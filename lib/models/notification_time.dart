class NotificationTime implements Comparable<NotificationTime> {
  const NotificationTime({required this.hour, required this.minute})
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  factory NotificationTime.fromJson(Map<String, dynamic> json) {
    final hour = (json['hour'] as num?)?.toInt();
    final minute = (json['minute'] as num?)?.toInt();
    return NotificationTime(
      hour: hour != null && hour >= 0 && hour < 24 ? hour : 9,
      minute: minute != null && minute >= 0 && minute < 60 ? minute : 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'hour': hour,
    'minute': minute,
  };

  String get label =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';

  int get sortValue => hour * 60 + minute;

  @override
  int compareTo(NotificationTime other) => sortValue.compareTo(other.sortValue);

  @override
  bool operator ==(Object other) =>
      other is NotificationTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}
