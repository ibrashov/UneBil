import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/app_language.dart';
import '../models/app_settings.dart';
import '../models/learning_fact.dart';
import '../models/notification_length.dart';
import '../models/notification_time.dart';
import '../models/topic.dart';
import 'fact_generator.dart';
import 'fact_deduplicator.dart';
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
  final Map<String, Future<int>> _generationTasks = <String, Future<int>>{};
  final Map<String, String> _generationErrors = <String, String>{};
  String? _lastError;

  List<Topic> get topics => List.unmodifiable(_topics);
  List<LearningFact> get facts => List.unmodifiable(_facts);
  AppSettings get settings => _settings;
  bool get loading => _loading;
  String? get generatingTopicId => _generationTasks.keys.firstOrNull;
  String? get lastError => _lastError;

  bool isGeneratingTopic(String topicId) =>
      _generationTasks.containsKey(topicId);

  String? generationErrorForTopic(String topicId) => _generationErrors[topicId];

  List<Topic> get enabledTopics =>
      _topics.where((topic) => topic.enabled).toList(growable: false);

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _topics = _storage.loadTopics();
    final cleanup = FactDeduplicator.cleanStoredFacts(_storage.loadFacts());
    _facts = cleanup.facts;
    _settings = _storage.loadSettings();
    if (cleanup.changed) {
      await _storage.saveFacts(_facts);
    }
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
        .map(
          (topic) =>
              topic.id == topicId ? topic.copyWith(title: trimmed) : topic,
        )
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
                  key: fact.key,
                )
              : fact,
        )
        .toList();
    await _storage.saveFacts(_facts);
    await _saveTopicsAndSchedule();
  }

  Future<void> toggleTopic(String topicId, bool enabled) async {
    _topics = _topics
        .map(
          (topic) =>
              topic.id == topicId ? topic.copyWith(enabled: enabled) : topic,
        )
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
    final times = <NotificationTime>{
      ..._settings.notificationTimes,
      time,
    }.toList()..sort();
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

  Future<int> generateFactsForTopic(
    String topicId, {
    int count = 1,
    bool silent = false,
  }) {
    final runningTask = _generationTasks[topicId];
    if (runningTask != null) {
      return runningTask;
    }

    final topic = _topics.where((topic) => topic.id == topicId).firstOrNull;
    if (topic == null) {
      return Future<int>.value(0);
    }

    _generationErrors.remove(topicId);
    if (!silent) {
      _lastError = null;
    }

    late final Future<int> task;
    task =
        _generateFactsForTopic(
          topic,
          language: _settings.language,
          length: _settings.length,
          count: count,
        ).whenComplete(() {
          if (identical(_generationTasks[topicId], task)) {
            _generationTasks.remove(topicId);
          }
          notifyListeners();
        });
    _generationTasks[topicId] = task;
    notifyListeners();
    return task;
  }

  Future<int> _generateFactsForTopic(
    Topic requestedTopic, {
    required AppLanguage language,
    required NotificationLength length,
    required int count,
  }) async {
    var addedCount = 0;
    try {
      final excludedFacts = _excludedFactsFor(requestedTopic, language);
      final generated = await _factGenerator.generateFacts(
        topic: requestedTopic.title,
        language: language,
        length: length,
        count: count,
        excludedFacts: excludedFacts,
      );
      if (generated.isEmpty) {
        throw StateError('empty facts response');
      }

      final currentTopic = _topics
          .where((topic) => topic.id == requestedTopic.id)
          .firstOrNull;
      if (currentTopic == null || currentTopic.title != requestedTopic.title) {
        return 0;
      }

      final now = DateTime.now();
      final usedFacts = <GeneratedFact>[
        ..._excludedFactsFor(currentTopic, language),
      ];
      final newFacts = <LearningFact>[];

      for (final fact in generated) {
        if (fact.title.trim().isEmpty ||
            fact.body.trim().isEmpty ||
            FactDeduplicator.containsDuplicate(fact, usedFacts)) {
          continue;
        }

        usedFacts.add(fact);
        newFacts.add(
          LearningFact(
            id: _uuid.v4(),
            topicId: currentTopic.id,
            topicTitle: currentTopic.title,
            title: fact.title,
            body: fact.body,
            language: language,
            length: length,
            createdAt: now,
            key: fact.key,
          ),
        );
      }

      if (newFacts.isEmpty) {
        throw const FactGenerationException(
          'AI не смог создать новый факт: все варианты уже есть в истории.',
        );
      }

      _facts = <LearningFact>[...newFacts, ..._facts].take(120).toList();
      await _storage.saveFacts(_facts);
      await _rescheduleNotifications();
      addedCount = newFacts.length;
      _generationErrors.remove(requestedTopic.id);
    } on FactGenerationException catch (error) {
      _generationErrors[requestedTopic.id] = error.message;
      _lastError = error.message;
    } catch (_) {
      final message =
          'Не удалось получить факт. Запусти backend или проверь AI-ключ.';
      _generationErrors[requestedTopic.id] = message;
      _lastError = message;
    }
    return addedCount;
  }

  Future<bool> showTestNotification() async {
    _lastError = null;
    try {
      await _scheduler.showTestNotification(
        settings: _settings,
        topics: _topics,
        facts: _facts,
      );
      notifyListeners();
      return true;
    } on NotificationPermissionException catch (error) {
      _lastError = error.message;
      notifyListeners();
      return false;
    } catch (_) {
      _lastError =
          'Не удалось показать тестовое уведомление. Проверь разрешения Android.';
      notifyListeners();
      return false;
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

  List<GeneratedFact> _excludedFactsFor(Topic topic, AppLanguage language) {
    return _facts
        .where((fact) => fact.topicId == topic.id && fact.language == language)
        .map(
          (fact) =>
              GeneratedFact(title: fact.title, body: fact.body, key: fact.key),
        )
        .take(120)
        .toList(growable: false);
  }
}
