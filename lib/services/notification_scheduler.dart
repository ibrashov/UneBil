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

abstract class FactNotificationScheduler {
  Future<void> initialize();

  Future<void> scheduleDailyFacts({
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

  @override
  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
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

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    _initialized = true;
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
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: _nextInstanceOf(time),
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: _nextInstanceOf(time),
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
}
