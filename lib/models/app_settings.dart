import 'app_language.dart';
import 'app_theme_mode.dart';
import 'app_time_zone.dart';
import 'interface_language.dart';
import 'notification_length.dart';
import 'notification_time.dart';

class AppSettings {
  const AppSettings({
    required this.language,
    required this.length,
    this.interfaceLanguage,
    this.themeMode = AppThemeMode.system,
    this.timeZone = AppTimeZone.device,
    this.notificationTimes = const <NotificationTime>[],
  });

  final AppLanguage language;
  final NotificationLength length;
  final InterfaceLanguage? interfaceLanguage;
  final AppThemeMode themeMode;
  final AppTimeZone timeZone;
  final List<NotificationTime> notificationTimes;

  static const defaultSettings = AppSettings(
    language: AppLanguage.ru,
    length: NotificationLength.medium,
    interfaceLanguage: null,
    themeMode: AppThemeMode.system,
    timeZone: AppTimeZone.device,
    notificationTimes: <NotificationTime>[],
  );

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawTimes = json['notificationTimes'];
    final times = rawTimes is List
        ? rawTimes
              .whereType<Map>()
              .map(
                (item) =>
                    NotificationTime.fromJson(Map<String, dynamic>.from(item)),
              )
              .toSet()
              .toList()
        : <NotificationTime>[];
    times.sort();

    return AppSettings(
      language: AppLanguage.fromCode(json['language'] as String?),
      length: NotificationLength.fromId(json['lengthMode'] as String?),
      interfaceLanguage: InterfaceLanguage.tryFromCode(
        json['interfaceLanguage'] as String?,
      ),
      themeMode: AppThemeMode.fromId(json['themeMode'] as String?),
      // Older builds always stored Kazakhstan even when the user had never
      // selected a zone. Migrate once to device time so every country gets
      // its own local 07:00; explicit choices made in this build are kept.
      timeZone: json['timeZoneBehaviorVersion'] == 1
          ? AppTimeZone.fromId(json['timeZone'] as String?)
          : AppTimeZone.device,
      notificationTimes: List<NotificationTime>.unmodifiable(times),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'language': language.code,
    'lengthMode': length.id,
    if (interfaceLanguage != null) 'interfaceLanguage': interfaceLanguage!.code,
    'themeMode': themeMode.id,
    'timeZone': timeZone.id,
    'timeZoneBehaviorVersion': 1,
    'notificationTimes': notificationTimes
        .map((time) => time.toJson())
        .toList(growable: false),
  };

  AppSettings copyWith({
    AppLanguage? language,
    NotificationLength? length,
    InterfaceLanguage? interfaceLanguage,
    AppThemeMode? themeMode,
    AppTimeZone? timeZone,
    List<NotificationTime>? notificationTimes,
  }) {
    final nextTimes = <NotificationTime>{
      ...(notificationTimes ?? this.notificationTimes),
    }.toList()..sort();

    return AppSettings(
      language: language ?? this.language,
      length: length ?? this.length,
      interfaceLanguage: interfaceLanguage ?? this.interfaceLanguage,
      themeMode: themeMode ?? this.themeMode,
      timeZone: timeZone ?? this.timeZone,
      notificationTimes: List<NotificationTime>.unmodifiable(nextTimes),
    );
  }
}
