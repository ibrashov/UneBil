import 'app_language.dart';
import 'app_time_zone.dart';
import 'interface_language.dart';
import 'notification_length.dart';
import 'notification_time.dart';

class AppSettings {
  const AppSettings({
    required this.language,
    required this.length,
    this.interfaceLanguage,
    this.timeZone = AppTimeZone.kazakhstan,
    this.notificationTimes = const <NotificationTime>[],
  });

  final AppLanguage language;
  final NotificationLength length;
  final InterfaceLanguage? interfaceLanguage;
  final AppTimeZone timeZone;
  final List<NotificationTime> notificationTimes;

  static const defaultSettings = AppSettings(
    language: AppLanguage.ru,
    length: NotificationLength.medium,
    interfaceLanguage: null,
    timeZone: AppTimeZone.kazakhstan,
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
      timeZone: AppTimeZone.fromId(json['timeZone'] as String?),
      notificationTimes: List<NotificationTime>.unmodifiable(times),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'language': language.code,
    'lengthMode': length.id,
    if (interfaceLanguage != null) 'interfaceLanguage': interfaceLanguage!.code,
    'timeZone': timeZone.id,
    'notificationTimes': notificationTimes
        .map((time) => time.toJson())
        .toList(growable: false),
  };

  AppSettings copyWith({
    AppLanguage? language,
    NotificationLength? length,
    InterfaceLanguage? interfaceLanguage,
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
      timeZone: timeZone ?? this.timeZone,
      notificationTimes: List<NotificationTime>.unmodifiable(nextTimes),
    );
  }
}
