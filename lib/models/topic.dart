import 'notification_interval.dart';

class Topic {
  const Topic({
    required this.id,
    required this.title,
    required this.enabled,
    required this.createdAt,
    this.notificationInterval = NotificationInterval.everyTwoHours,
    this.notificationId = 0,
    this.nextNotificationAt,
  });

  final String id;
  final String title;
  final bool enabled;
  final DateTime createdAt;
  final NotificationInterval notificationInterval;

  /// The first ID in this topic's reserved notification ID block.
  final int notificationId;
  final DateTime? nextNotificationAt;

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as String,
      title: json['title'] as String,
      enabled: json['enabled'] as bool? ?? true,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      notificationInterval: NotificationInterval.fromId(
        json['notificationInterval'] as String?,
      ),
      notificationId: (json['notificationId'] as num?)?.toInt() ?? 0,
      nextNotificationAt: DateTime.tryParse(
        json['nextNotificationAt'] as String? ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'enabled': enabled,
    'createdAt': createdAt.toIso8601String(),
    'notificationInterval': notificationInterval.id,
    'notificationId': notificationId,
    if (nextNotificationAt != null)
      'nextNotificationAt': nextNotificationAt!.toIso8601String(),
  };

  Topic copyWith({
    String? title,
    bool? enabled,
    NotificationInterval? notificationInterval,
    int? notificationId,
    DateTime? nextNotificationAt,
  }) {
    return Topic(
      id: id,
      title: title ?? this.title,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
      notificationInterval: notificationInterval ?? this.notificationInterval,
      notificationId: notificationId ?? this.notificationId,
      nextNotificationAt: nextNotificationAt ?? this.nextNotificationAt,
    );
  }
}
