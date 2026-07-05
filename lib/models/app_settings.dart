import 'app_language.dart';
import 'notification_length.dart';
import 'notification_time.dart';

class AppSettings {
  const AppSettings({
    required this.language,
    required this.length,
    required this.notificationTimes,
  });

  final AppLanguage language;
  final NotificationLength length;
  final List<NotificationTime> notificationTimes;

  static const defaultSettings = AppSettings(
    language: AppLanguage.ru,
    length: NotificationLength.medium,
    notificationTimes: <NotificationTime>[
      NotificationTime(hour: 9, minute: 0),
    ],
  );

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawTimes = json['notificationTimes'];
    final times = rawTimes is List
        ? rawTimes
              .whereType<Map>()
              .map((item) => NotificationTime.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
        : <NotificationTime>[];
    times.sort();

    return AppSettings(
      language: AppLanguage.fromCode(json['language'] as String?),
      length: NotificationLength.fromId(json['lengthMode'] as String?),
      notificationTimes:
          times.isEmpty ? defaultSettings.notificationTimes : times,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'language': language.code,
    'lengthMode': length.id,
    'notificationTimes': notificationTimes
        .map((time) => time.toJson())
        .toList(),
  };

  AppSettings copyWith({
    AppLanguage? language,
    NotificationLength? length,
    List<NotificationTime>? notificationTimes,
  }) {
    final nextTimes = List<NotificationTime>.from(
      notificationTimes ?? this.notificationTimes,
    )..sort();

    return AppSettings(
      language: language ?? this.language,
      length: length ?? this.length,
      notificationTimes: nextTimes,
    );
  }
}
