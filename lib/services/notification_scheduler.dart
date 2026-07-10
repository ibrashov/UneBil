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

class PlannedFactNotification {
  const PlannedFactNotification({
    required this.id,
    required this.topicId,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });

  final int id;
  final String topicId;
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
    final topicFacts = facts
        .where(
          (fact) =>
              fact.topicId == topic.id &&
              fact.language == settings.language &&
              fact.length == settings.length,
        )
        .toList()
      ..sort((first, second) => first.createdAt.compareTo(second.createdAt));

    if (topicFacts.isEmpty) {
      continue;
    }

    final interval = topic.notificationInterval.duration;
    for (var slot = 0; slot < notificationsPerTopic; slot += 1) {
      final scheduledAt = now.add(interval * (slot + 1));
      final rotationIndex =
          (scheduledAt.millisecondsSinceEpoch ~/ interval.inMilliseconds) %
              topicFacts.length;
      final fact = topicFacts[rotationIndex];
      planned.add(
        PlannedFactNotification(
          id: topic.notificationId + slot,
          topicId: topic.id,
          scheduledAt: scheduledAt,
          title: fact.title,
          body: fact.body,
        ),
      );
    }
  }

  return planned;
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

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

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
    await _plugin.initialize(settings: settings);
    _initialized = true;
    await _ensureNotificationsAllowed(requestPermission: true);
  }

  @override
  Future<void> scheduleFacts({
    required AppSettings settings,
    required List<Topic> topics,
    required List<LearningFact> facts,
  }) async {
    if (kIsWeb) {
      return;
    }
    await initialize();

    // Clear the old bounded queue first, so interval and topic changes cannot
    // leave duplicate or disabled-topic notifications behind.
    await _plugin.cancelAllPendingNotifications();
    if (!await _ensureNotificationsAllowed(requestPermission: false)) {
      return;
    }

    final planned = buildIntervalNotificationPlan(
      settings: settings,
      topics: topics,
      facts: facts,
      now: tz.TZDateTime.now(tz.local),
    );
    for (final notification in planned) {
      await _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: tz.TZDateTime.from(notification.scheduledAt, tz.local),
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: notification.topicId,
      );
    }
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

    if (!await _ensureNotificationsAllowed(requestPermission: false)) {
      throw const NotificationPermissionException(
        'Уведомления запрещены для UneBil. Разреши их в настройках Android.',
      );
    }

    await _plugin.show(
      id: 9000,
      title: _testTitle(settings.language),
      body: _testBody(settings.language),
      notificationDetails: _notificationDetails,
      payload: 'test-notification',
    );
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

  NotificationDetails get _notificationDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      'unebil_learning_facts',
      'Learning facts',
      channelDescription: 'Short learning facts for selected topics',
      importance: Importance.high,
      priority: Priority.high,
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
