class NotificationTime implements Comparable<NotificationTime> {
  const NotificationTime({required this.hour, required this.minute});

  final int hour;
  final int minute;

  factory NotificationTime.fromJson(Map<String, dynamic> json) {
    return NotificationTime(
      hour: (json['hour'] as num?)?.toInt() ?? 9,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'hour': hour,
    'minute': minute,
  };

  String get label {
    final hourText = hour.toString().padLeft(2, '0');
    final minuteText = minute.toString().padLeft(2, '0');
    return '$hourText:$minuteText';
  }

  int get sortValue => hour * 60 + minute;

  @override
  int compareTo(NotificationTime other) => sortValue.compareTo(other.sortValue);

  @override
  bool operator ==(Object other) {
    return other is NotificationTime &&
        other.hour == hour &&
        other.minute == minute;
  }

  @override
  int get hashCode => Object.hash(hour, minute);
}
