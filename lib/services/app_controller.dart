import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/app_language.dart';
import '../models/app_settings.dart';
import '../models/learning_fact.dart';
import '../models/notification_length.dart';
import '../models/notification_time.dart';
import '../models/topic.dart';
import 'fact_generator.dart';
import 'notification_scheduler.dart';
import 'storage_service.dart';

class AppController extends ChangeNotifier {
  AppController(
    this._storage,
    this._factGenerator,
    this._scheduler, {
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final StorageService _storage;
  final FactGenerator _factGenerator;
  final FactNotificationScheduler _scheduler;
  final Uuid _uuid;

  List<Topic> _topics = <Topic>[];
  List<LearningFact> _facts = <LearningFact>[];
  AppSettings _settings = AppSettings.defaultSettings;
  bool _loading = true;
  String? _generatingTopicId;
  String? _lastError;

  List<Topic> get topics => List.unmodifiable(_topics);
  List<LearningFact> get facts => List.unmodifiable(_facts);
  AppSettings get settings => _settings;
  bool get loading => _loading;
  String? get generatingTopicId => _generatingTopicId;
  String? get lastError => _lastError;

  List<Topic> get enabledTopics =>
      _topics.where((topic) => topic.enabled).toList(growable: false);

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _topics = _storage.loadTopics();
    _facts = _storage.loadFacts();
    _settings = _storage.loadSettings();
    await _scheduler.initialize();
    await _rescheduleNotifications();
    _loading = false;
    notifyListeners();
  }

  List<LearningFact> factsForTopic(String topicId) {
    return _facts
        .where((fact) => fact.topicId == topicId)
        .toList(growable: false);
  }

  Future<void> addTopic(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final topic = Topic(
      id: _uuid.v4(),
      title: trimmed,
      enabled: true,
      createdAt: DateTime.now(),
    );
    _topics = <Topic>[topic, ..._topics];
    await _saveTopicsAndSchedule();
    await generateFactsForTopic(
      topic.id,
      count: _settings.notificationTimes.length.clamp(1, 3),
      silent: true,
    );
  }

  Future<void> renameTopic(String topicId, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }

    _topics = _topics
        .map((topic) => topic.id == topicId ? topic.copyWith(title: trimmed) : topic)
        .toList();
    _facts = _facts
        .map(
          (fact) => fact.topicId == topicId
              ? LearningFact(
                  id: fact.id,
                  topicId: fact.topicId,
                  topicTitle: trimmed,
                  title: fact.title,
                  body: fact.body,
                  language: fact.language,
                  length: fact.length,
                  createdAt: fact.createdAt,
                )
              : fact,
        )
        .toList();
    await _storage.saveFacts(_facts);
    await _saveTopicsAndSchedule();
  }

  Future<void> toggleTopic(String topicId, bool enabled) async {
    _topics = _topics
        .map((topic) => topic.id == topicId ? topic.copyWith(enabled: enabled) : topic)
        .toList();
    await _saveTopicsAndSchedule();
  }

  Future<void> deleteTopic(String topicId) async {
    _topics = _topics.where((topic) => topic.id != topicId).toList();
    _facts = _facts.where((fact) => fact.topicId != topicId).toList();
    await _storage.saveTopics(_topics);
    await _storage.saveFacts(_facts);
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> updateLanguage(AppLanguage language) {
    return updateSettings(_settings.copyWith(language: language));
  }

  Future<void> updateLength(NotificationLength length) {
    return updateSettings(_settings.copyWith(length: length));
  }

  Future<void> addNotificationTime(NotificationTime time) {
    final times = <NotificationTime>{..._settings.notificationTimes, time}.toList()
      ..sort();
    return updateSettings(_settings.copyWith(notificationTimes: times));
  }

  Future<void> removeNotificationTime(NotificationTime time) {
    final times = _settings.notificationTimes
        .where((candidate) => candidate != time)
        .toList();
    return updateSettings(_settings.copyWith(notificationTimes: times));
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    await _storage.saveSettings(_settings);
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> generateFactsForTopic(
    String topicId, {
    int count = 1,
    bool silent = false,
  }) async {
    final topic = _topics.where((topic) => topic.id == topicId).firstOrNull;
    if (topic == null) {
      return;
    }

    if (!silent) {
      _generatingTopicId = topicId;
      _lastError = null;
      notifyListeners();
    }

    try {
      final generated = await _factGenerator.generateFacts(
        topic: topic.title,
        language: _settings.language,
        length: _settings.length,
        count: count,
      );
      final now = DateTime.now();
      final newFacts = generated
          .map(
            (fact) => LearningFact(
              id: _uuid.v4(),
              topicId: topic.id,
              topicTitle: topic.title,
              title: fact.title,
              body: fact.body,
              language: _settings.language,
              length: _settings.length,
              createdAt: now,
            ),
          )
          .toList();

      _facts = <LearningFact>[...newFacts, ..._facts].take(120).toList();
      await _storage.saveFacts(_facts);
      await _rescheduleNotifications();
    } catch (_) {
      _lastError = 'Не удалось получить факт. Проверь backend или интернет.';
    } finally {
      if (!silent) {
        _generatingTopicId = null;
      }
      notifyListeners();
    }
  }

  Future<void> _saveTopicsAndSchedule() async {
    await _storage.saveTopics(_topics);
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> _rescheduleNotifications() {
    return _scheduler.scheduleDailyFacts(
      settings: _settings,
      topics: _topics,
      facts: _facts,
    );
  }
}
