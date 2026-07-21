import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../models/app_language.dart';
import '../models/app_settings.dart';
import '../models/app_time_zone.dart';
import '../models/learning_fact.dart';
import '../models/notification_interval.dart';
import '../models/notification_length.dart';
import '../models/topic.dart';
import 'fact_generator.dart';
import 'fact_deduplicator.dart';
import 'notification_scheduler.dart';
import 'storage_service.dart';

class AppController extends ChangeNotifier with WidgetsBindingObserver {
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

  static const _notificationIdStart =
      NotificationScheduler.topicNotificationIdStart;
  static const _notificationIdBlockSize =
      NotificationScheduler.notificationsPerTopic;
  static const _maximumNotificationBaseId =
      2147483647 - (_notificationIdBlockSize - 1);
  static const _notificationIdBlockCount =
      (_maximumNotificationBaseId - _notificationIdStart + 1) ~/
      _notificationIdBlockSize;

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
    final normalizedTopics = _normalizeTopicNotificationIds(
      _storage.loadTopics(),
    );
    _topics = normalizedTopics.topics;
    final cleanup = FactDeduplicator.cleanStoredFacts(_storage.loadFacts());
    _facts = cleanup.facts;
    _settings = _storage.loadSettings();
    if (normalizedTopics.changed) {
      await _storage.saveTopics(_topics);
    }
    if (cleanup.changed) {
      await _storage.saveFacts(_facts);
    }
    await _scheduler.initialize();
    await _rescheduleNotifications();
    _loading = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading) {
      unawaited(_rescheduleNotifications());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  List<LearningFact> factsForTopic(String topicId) {
    return _facts
        .where((fact) => fact.topicId == topicId)
        .toList(growable: false);
  }

  /// Returns the same upcoming queue that is sent to Android notifications.
  /// The UI uses it to show when each cached fact will appear next.
  List<PlannedFactNotification> notificationPlanForTopic(
    String topicId, {
    DateTime? now,
  }) {
    return buildIntervalNotificationPlan(
      settings: _settings,
      topics: _topics
          .where((topic) => topic.id == topicId)
          .toList(growable: false),
      facts: _facts,
      now: now ?? DateTime.now(),
    );
  }

  Future<void> addTopic(
    String title, {
    NotificationInterval interval = NotificationInterval.everyTwoHours,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final id = _uuid.v4();
    final topic = Topic(
      id: id,
      title: trimmed,
      enabled: true,
      createdAt: DateTime.now(),
      notificationInterval: interval,
      notificationId: _allocateNotificationId(
        id,
        _topics.map((topic) => topic.notificationId).toSet(),
      ),
      nextNotificationAt: DateTime.now().add(interval.duration),
    );
    _topics = <Topic>[topic, ..._topics];
    await _saveTopicsAndSchedule();
    await generateFactsForTopic(topic.id, count: 1, silent: true);
  }

  Future<void> renameTopic(String topicId, String title) {
    final topic = _topics
        .where((candidate) => candidate.id == topicId)
        .firstOrNull;
    if (topic == null) {
      return Future<void>.value();
    }
    return updateTopic(
      topicId,
      title: title,
      interval: topic.notificationInterval,
    );
  }

  Future<void> updateTopicInterval(
    String topicId,
    NotificationInterval interval,
  ) {
    final topic = _topics
        .where((candidate) => candidate.id == topicId)
        .firstOrNull;
    if (topic == null || topic.notificationInterval == interval) {
      return Future<void>.value();
    }
    return updateTopic(topicId, title: topic.title, interval: interval);
  }

  Future<void> updateTopic(
    String topicId, {
    required String title,
    required NotificationInterval interval,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final now = DateTime.now();

    _topics = _topics.map((topic) {
      if (topic.id != topicId) {
        return topic;
      }
      final intervalChanged = topic.notificationInterval != interval;
      return topic.copyWith(
        title: trimmed,
        notificationInterval: interval,
        nextNotificationAt: intervalChanged
            ? now.add(interval.duration)
            : topic.nextNotificationAt,
      );
    }).toList();
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
    final now = DateTime.now();
    _topics = _topics.map((topic) {
      if (topic.id != topicId) {
        return topic;
      }
      return topic.copyWith(
        enabled: enabled,
        nextNotificationAt: enabled && !topic.enabled
            ? now.add(topic.notificationInterval.duration)
            : topic.nextNotificationAt,
      );
    }).toList();
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

  Future<void> updateTimeZone(AppTimeZone timeZone) {
    return updateSettings(_settings.copyWith(timeZone: timeZone));
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
          'Не удалось запланировать тестовый факт. Проверь уведомления и разрешение точных будильников Android.';
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
    return _scheduler.scheduleFacts(
      settings: _settings,
      topics: _topics,
      facts: _facts,
    );
  }

  ({List<Topic> topics, bool changed}) _normalizeTopicNotificationIds(
    List<Topic> topics,
  ) {
    final usedIds = <int>{};
    final now = DateTime.now();
    var changed = false;
    final normalized = <Topic>[];

    for (final topic in topics) {
      var notificationId = topic.notificationId;
      if (!_isValidUnusedNotificationId(notificationId, usedIds)) {
        notificationId = _allocateNotificationId(topic.id, usedIds);
        changed = true;
      }
      usedIds.add(notificationId);
      final nextNotificationAt =
          topic.nextNotificationAt ??
          now.add(topic.notificationInterval.duration);
      if (topic.nextNotificationAt == null) {
        changed = true;
      }
      normalized.add(
        notificationId == topic.notificationId &&
                nextNotificationAt == topic.nextNotificationAt
            ? topic
            : topic.copyWith(
                notificationId: notificationId,
                nextNotificationAt: nextNotificationAt,
              ),
      );
    }
    return (topics: normalized, changed: changed);
  }

  bool _isValidUnusedNotificationId(int id, Set<int> usedIds) {
    return id >= _notificationIdStart &&
        id <= _maximumNotificationBaseId &&
        (id - _notificationIdStart) % _notificationIdBlockSize == 0 &&
        !usedIds.contains(id);
  }

  int _allocateNotificationId(String seed, Set<int> usedIds) {
    final firstBlock = _stableHash(seed) % _notificationIdBlockCount;
    for (var offset = 0; offset < _notificationIdBlockCount; offset += 1) {
      final block = (firstBlock + offset) % _notificationIdBlockCount;
      final candidate = _notificationIdStart + block * _notificationIdBlockSize;
      if (!usedIds.contains(candidate)) {
        return candidate;
      }
    }
    throw StateError('No notification IDs remain available.');
  }

  int _stableHash(String value) {
    var hash = 2166136261;
    for (final codeUnit in value.codeUnits) {
      hash = (hash ^ codeUnit) * 16777619;
      hash &= 0x7fffffff;
    }
    return hash;
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
