import 'interface_language.dart';

enum NotificationInterval {
  hourly('hourly', 1),
  everyTwoHours('everyTwoHours', 2),
  everyThreeHours('everyThreeHours', 3);

  const NotificationInterval(this.id, this.hours);

  final String id;
  final int hours;

  Duration get duration => Duration(hours: hours);

  static String selectorLabel(InterfaceLanguage language) {
    return switch (language) {
      InterfaceLanguage.ru => 'Интервал уведомлений',
      InterfaceLanguage.kk => 'Хабарландыру аралығы',
      InterfaceLanguage.en => 'Notification interval',
    };
  }

  String label(InterfaceLanguage language) {
    return switch (language) {
      InterfaceLanguage.ru => switch (this) {
        NotificationInterval.hourly => 'Каждый час',
        NotificationInterval.everyTwoHours => 'Каждые 2 часа',
        NotificationInterval.everyThreeHours => 'Каждые 3 часа',
      },
      InterfaceLanguage.kk => switch (this) {
        NotificationInterval.hourly => 'Әр сағат сайын',
        NotificationInterval.everyTwoHours => 'Әр 2 сағат сайын',
        NotificationInterval.everyThreeHours => 'Әр 3 сағат сайын',
      },
      InterfaceLanguage.en => switch (this) {
        NotificationInterval.hourly => 'Every hour',
        NotificationInterval.everyTwoHours => 'Every 2 hours',
        NotificationInterval.everyThreeHours => 'Every 3 hours',
      },
    };
  }

  static NotificationInterval fromId(String? id) {
    return NotificationInterval.values.firstWhere(
      (interval) => interval.id == id,
      orElse: () => NotificationInterval.everyTwoHours,
    );
  }
}
