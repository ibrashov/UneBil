import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_language.dart';
import '../models/app_settings.dart';
import '../models/learning_fact.dart';
import '../models/topic.dart';

class NotificationPermissionException implements Exception {
  const NotificationPermissionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NotificationTarget {
  const NotificationTarget({required this.topicId, required this.factId});

  final String topicId;
  final String factId;

  String toPayload() => jsonEncode(<String, String>{
    'topicId': topicId,
    'factId': factId,
  });

  static NotificationTarget? tryParse(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final topicId = decoded['topicId'];
      final factId = decoded['factId'];
      if (topicId is! String || factId is! String || factId.isEmpty) {
        return null;
      }
      return NotificationTarget(topicId: topicId, factId: factId);
    } catch (_) {
      // Notifications scheduled by older versions used a plain topic ID.
      return null;
    }
  }
}

class PlannedFactNotification {
  const PlannedFactNotification({
    required this.id,
    required this.topicId,
    required this.factId,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });

  final int id;
  final String topicId;
  final String factId;
  final DateTime scheduledAt;
  final String title;
  final String body;
}

/// Creates a bounded, rotating notification queue from cached facts only.
@visibleForTesting
List<PlannedFactNotification> buildIntervalNotificationPlan({
  required AppSettings settings,
  required List<Topic> topics,
  required List<LearningFact> facts,
  required DateTime now,
  int notificationsPerTopic = NotificationScheduler.notificationsPerTopic,
}) {
  final planned = <PlannedFactNotification>[];

  for (final topic in topics.where((topic) => topic.enabled)) {
    final topicFacts = _notificationFactsForTopic(topic, settings, facts);

    if (topicFacts.isEmpty) {
      continue;
    }

    final interval = topic.notificationInterval.duration;
    final firstScheduledAt = _nextScheduledAt(topic, now);
    for (var slot = 0; slot < notificationsPerTopic; slot += 1) {
      final scheduledAt = firstScheduledAt.add(interval * slot);
      final rotationIndex =
          (scheduledAt.millisecondsSinceEpoch ~/ interval.inMilliseconds) %
          topicFacts.length;
      final fact = topicFacts[rotationIndex];
      planned.add(
        PlannedFactNotification(
          id: topic.notificationId + slot,
          topicId: topic.id,
          factId: fact.id,
          scheduledAt: scheduledAt,
          title: fact.title,
          body: fact.body,
        ),
      );
    }
  }

  return planned;
}

DateTime _nextScheduledAt(Topic topic, DateTime now) {
  final interval = topic.notificationInterval.duration;
  final anchor = topic.nextNotificationAt ?? now.add(interval);
  if (anchor.isAfter(now)) {
    return anchor;
  }

  final elapsedIntervals =
      now.difference(anchor).inMilliseconds ~/ interval.inMilliseconds;
  return anchor.add(interval * (elapsedIntervals + 1));
}

List<LearningFact> _notificationFactsForTopic(
  Topic topic,
  AppSettings settings,
  List<LearningFact> facts,
) {
  final allTopicFacts = facts
      .where((fact) => fact.topicId == topic.id)
      .toList(growable: false);
  final matchingFacts = allTopicFacts
      .where(
        (fact) =>
            fact.language == settings.language &&
            fact.length == settings.length,
      )
      .toList(growable: false);
  final selectedFacts = matchingFacts.isNotEmpty
      ? matchingFacts
      : allTopicFacts;

  return selectedFacts
    ..sort((first, second) => first.createdAt.compareTo(second.createdAt));
}

abstract class FactNotificationScheduler {
  Future<void> initialize();

  Future<void> scheduleFacts({
    required AppSettings settings,
    required List<Topic> topics,
    required List<LearningFact> facts,
  });

  Future<void> showTestNotification({
    required AppSettings settings,
    required List<Topic> topics,
    required List<LearningFact> facts,
  });
}

class NotificationScheduler implements FactNotificationScheduler {
  NotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const notificationsPerTopic = 12;
  static const topicNotificationIdStart = 10000;
  static const testNotificationId = 9000;

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<NotificationTarget> _notificationTaps =
      StreamController<NotificationTarget>.broadcast(sync: true);
  bool _initialized = false;
  bool _requestedExactAlarmPermission = false;
  Future<void> _scheduleQueue = Future<void>.value();

  @override
  Future<void> initialize() async {
    if (kIsWeb || _initialized) {
      return;
    }

    tz.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final target = NotificationTarget.tryParse(response.payload);
        if (target != null) {
          _notificationTaps.add(target);
        }
      },
    );
    _initialized = true;
    await _ensureNotificationsAllowed(requestPermission: true);
  }

  @override
  Future<void> scheduleFacts({
    required AppSettings settings,
    required List<Topic> topics,
    required List<LearningFact> facts,
  }) {
    // Rescheduling can be triggered by app resume while an AI generation or a
    // settings update is already rebuilding the queue. Keep cancellation and
    // replacement atomic so an older refresh cannot erase a newer schedule.
    final settingsSnapshot = settings;
    final topicsSnapshot = List<Topic>.of(topics, growable: false);
    final factsSnapshot = List<LearningFact>.of(facts, growable: false);
    final operation = _scheduleQueue.then(
      (_) => _scheduleFactsNow(
        settings: settingsSnapshot,
        topics: topicsSnapshot,
        facts: factsSnapshot,
      ),
    );
    _scheduleQueue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _scheduleFactsNow({
    required AppSettings settings,
    required List<Topic> topics,
    required List<LearningFact> facts,
  }) async {
    if (kIsWeb) {
      return;
    }
    await initialize();
    _useTimeZone(settings);

    if (!await _ensureNotificationsAllowed(requestPermission: false)) {
      return;
    }

    final planned = buildIntervalNotificationPlan(
      settings: settings,
      topics: topics,
      facts: facts,
      now: tz.TZDateTime.now(tz.local),
    );

    await _cancelPendingFactNotifications();
    if (planned.isEmpty) {
      return;
    }

    await _requestExactAlarmPermissionOnce();
    final scheduleMode = await _androidScheduleMode();
    for (final notification in planned) {
      await _scheduleNotification(notification, scheduleMode: scheduleMode);
    }
  }

  Stream<NotificationTarget> get notificationTaps =>
      _notificationTaps.stream;

  Future<NotificationTarget?> get launchNotification async {
    if (kIsWeb) {
      return null;
    }
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) {
      return null;
    }
    return NotificationTarget.tryParse(details?.notificationResponse?.payload);
  }

  @override
  Future<void> showTestNotification({
    required AppSettings settings,
    required List<Topic> topics,
    required List<LearningFact> facts,
  }) async {
    if (kIsWeb) {
      return;
    }
    await initialize();
    _useTimeZone(settings);

    if (!await _ensureNotificationsAllowed(requestPermission: false)) {
      throw const NotificationPermissionException(
        'Уведомления запрещены для UneBil. Разреши их в настройках Android.',
      );
    }

    final planned = buildIntervalNotificationPlan(
      settings: settings,
      topics: topics,
      facts: facts,
      now: tz.TZDateTime.now(tz.local),
      notificationsPerTopic: 1,
    );
    final factNotification = planned.firstOrNull;
    final body = factNotification?.body ?? _testBody(settings.language);
    await _requestExactAlarmPermissionOnce();
    final scheduleMode = await _androidScheduleMode();
    if (_androidPlugin != null &&
        scheduleMode == AndroidScheduleMode.inexactAllowWhileIdle) {
      throw const NotificationPermissionException(
        'Разреши для UneBil "Будильники и напоминания", вернись в приложение и нажми проверку ещё раз.',
      );
    }
    await _scheduleNotification(
      PlannedFactNotification(
        id: testNotificationId,
        topicId: factNotification?.topicId ?? 'test-notification',
        factId: factNotification?.factId ?? '',
        scheduledAt: tz.TZDateTime.now(
          tz.local,
        ).add(const Duration(seconds: 15)),
        title: factNotification?.title ?? _testTitle(settings.language),
        body: body,
      ),
      scheduleMode: scheduleMode,
    );
  }

  Future<void> _cancelPendingFactNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.id >= topicNotificationIdStart) {
        await _plugin.cancel(id: notification.id);
      }
    }
  }

  void _useTimeZone(AppSettings settings) {
    tz.setLocalLocation(tz.getLocation(settings.timeZone.locationName));
  }

  Future<bool> _ensureNotificationsAllowed({
    required bool requestPermission,
  }) async {
    final android = _androidPlugin;
    if (android == null) {
      return true;
    }

    if (requestPermission) {
      final granted = await android.requestNotificationsPermission();
      if (granted == false) {
        return false;
      }
    }

    return await android.areNotificationsEnabled() ?? true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin {
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  Future<void> _scheduleNotification(
    PlannedFactNotification notification, {
    required AndroidScheduleMode scheduleMode,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: tz.TZDateTime.from(notification.scheduledAt, tz.local),
        notificationDetails: _notificationDetailsFor(notification.body),
        androidScheduleMode: scheduleMode,
        payload: NotificationTarget(
          topicId: notification.topicId,
          factId: notification.factId,
        ).toPayload(),
      );
    } catch (_) {
      if (scheduleMode == AndroidScheduleMode.inexactAllowWhileIdle) {
        rethrow;
      }
      await _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: tz.TZDateTime.from(notification.scheduledAt, tz.local),
        notificationDetails: _notificationDetailsFor(notification.body),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: NotificationTarget(
          topicId: notification.topicId,
          factId: notification.factId,
        ).toPayload(),
      );
    }
  }

  Future<void> _requestExactAlarmPermissionOnce() async {
    if (_requestedExactAlarmPermission) {
      return;
    }

    final android = _androidPlugin;
    if (android == null) {
      return;
    }

    _requestedExactAlarmPermission = true;
    final canScheduleExact = await android.canScheduleExactNotifications();
    if (canScheduleExact == false) {
      await android.requestExactAlarmsPermission();
    }
  }

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    final canScheduleExact =
        await _androidPlugin?.canScheduleExactNotifications() ?? true;
    return canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  NotificationDetails _notificationDetailsFor(String body) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'unebil_learning_facts',
          'Learning facts',
          channelDescription: 'Short learning facts for selected topics',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  String _testTitle(AppLanguage language) {
    return switch (language) {
      AppLanguage.ru => 'Проверка UneBil',
      AppLanguage.kk => 'UneBil тексеру',
      AppLanguage.en => 'UneBil test',
    };
  }

  String _testBody(AppLanguage language) {
    return switch (language) {
      AppLanguage.ru => 'Если ты видишь это, уведомления работают.',
      AppLanguage.kk => 'Осы хабарлама көрінсе, ескертулер жұмыс істейді.',
      AppLanguage.en => 'If you can see this, notifications are working.',
    };
  }
}

class NoopNotificationScheduler implements FactNotificationScheduler {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleFacts({
    required AppSettings settings,
    required List<Topic> topics,
    required List<LearningFact> facts,
  }) async {}

  @override
  Future<void> showTestNotification({
    required AppSettings settings,
    required List<Topic> topics,
    required List<LearningFact> facts,
  }) async {}
}
