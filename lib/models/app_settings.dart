import 'app_language.dart';
import 'notification_length.dart';

class AppSettings {
  const AppSettings({required this.language, required this.length});

  final AppLanguage language;
  final NotificationLength length;

  static const defaultSettings = AppSettings(
    language: AppLanguage.ru,
    length: NotificationLength.medium,
  );

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      language: AppLanguage.fromCode(json['language'] as String?),
      length: NotificationLength.fromId(json['lengthMode'] as String?),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'language': language.code,
    'lengthMode': length.id,
  };

  AppSettings copyWith({AppLanguage? language, NotificationLength? length}) {
    return AppSettings(
      language: language ?? this.language,
      length: length ?? this.length,
    );
  }
}
