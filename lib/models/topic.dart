class Topic {
  const Topic({
    required this.id,
    required this.title,
    required this.enabled,
    required this.createdAt,
  });

  final String id;
  final String title;
  final bool enabled;
  final DateTime createdAt;

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as String,
      title: json['title'] as String,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'enabled': enabled,
    'createdAt': createdAt.toIso8601String(),
  };

  Topic copyWith({String? title, bool? enabled}) {
    return Topic(
      id: id,
      title: title ?? this.title,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
    );
  }
}
