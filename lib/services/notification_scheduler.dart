import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_language.dart';
import '../models/app_settings.dart';
import '../models/learning_fact.dart';
import '../models/notification_time.dart';
import '../models/topic.dart';

class NotificationPermissionException implements Exception {
  const NotificationPermissionException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class FactNotificationScheduler {
  Future<void> initialize();

  Future<void> scheduleDailyFacts({
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

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _requestedExactAlarmPermission = false;

  @override
  Future<void> initialize() async {
    if (kIsWeb) {
      return;
    }

    if (!_initialized) {
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
    }

    await _ensureNotificationsAllowed(requestPermission: true);
    await _requestExactAlarmPermissionOnce();
  }

  @override
  Future<void> scheduleDailyFacts({
    required AppSettings settings,
    required List<Topic> topics,
    required List<LearningFact> facts,
  }) async {
    if (kIsWeb) {
      return;
    }
    await initialize();
    await _plugin.cancelAllPendingNotifications();

    final notificationsAllowed = await _ensureNotificationsAllowed(
      requestPermission: true,
    );
    if (!notificationsAllowed) {
      return;
    }

    final enabledTopics = topics.where((topic) => topic.enabled).toList();
    if (enabledTopics.isEmpty || settings.notificationTimes.isEmpty) {
      return;
    }

    for (var index = 0; index < settings.notificationTimes.length; index++) {
      final topic = enabledTopics[index % enabledTopics.length];
      final fact = _bestFactForTopic(topic, settings, facts);
      final title = fact?.title ?? topic.title;
      final body = fact?.body ?? _emptyFactText(topic.title, settings.language);

      await _scheduleSafely(
        id: 1000 + index,
        time: settings.notificationTimes[index],
        title: title,
        body: body,
        payload: topic.id,
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

    final notificationsAllowed = await _ensureNotificationsAllowed(
      requestPermission: true,
    );
    if (!notificationsAllowed) {
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

  LearningFact? _bestFactForTopic(
    Topic topic,
    AppSettings settings,
    List<LearningFact> facts,
  ) {
    for (final fact in facts) {
      if (fact.topicId == topic.id &&
          fact.language == settings.language &&
          fact.length == settings.length) {
        return fact;
      }
    }
    return null;
  }

  Future<void> _scheduleSafely({
    required int id,
    required NotificationTime time,
    required String title,
    required String body,
    required String payload,
  }) async {
    final scheduledDate = _nextInstanceOf(time);
    final scheduleMode = await _androidScheduleMode();

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: _notificationDetails,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } catch (_) {
      if (scheduleMode == AndroidScheduleMode.inexactAllowWhileIdle) {
        rethrow;
      }

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    }
  }

  tz.TZDateTime _nextInstanceOf(NotificationTime time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
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

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin {
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  NotificationDetails get _notificationDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      'unebil_daily_facts',
      'Daily learning facts',
      channelDescription: 'Short learning facts for selected topics',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  String _emptyFactText(String topic, AppLanguage language) {
    return switch (language) {
      AppLanguage.ru =>
        'Открой UneBil и сгенерируй новый короткий факт по теме "$topic".',
      AppLanguage.kk =>
        'UneBil ашып, "$topic" тақырыбы бойынша жаңа қысқа дерек жаса.',
      AppLanguage.en =>
        'Open UneBil and generate a new short fact about "$topic".',
    };
  }

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
  Future<void> scheduleDailyFacts({
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
