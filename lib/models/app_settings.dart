import 'app_language.dart';
import 'app_time_zone.dart';
import 'notification_length.dart';

class AppSettings {
  const AppSettings({
    required this.language,
    required this.length,
    this.timeZone = AppTimeZone.kazakhstan,
  });

  final AppLanguage language;
  final NotificationLength length;
  final AppTimeZone timeZone;

  static const defaultSettings = AppSettings(
    language: AppLanguage.ru,
    length: NotificationLength.medium,
    timeZone: AppTimeZone.kazakhstan,
  );

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      language: AppLanguage.fromCode(json['language'] as String?),
      length: NotificationLength.fromId(json['lengthMode'] as String?),
      timeZone: AppTimeZone.fromId(json['timeZone'] as String?),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'language': language.code,
    'lengthMode': length.id,
    'timeZone': timeZone.id,
  };

  AppSettings copyWith({
    AppLanguage? language,
    NotificationLength? length,
    AppTimeZone? timeZone,
  }) {
    return AppSettings(
      language: language ?? this.language,
      length: length ?? this.length,
      timeZone: timeZone ?? this.timeZone,
    );
  }
}
