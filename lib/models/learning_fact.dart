import 'app_language.dart';
import 'notification_length.dart';

class GeneratedFact {
  const GeneratedFact({required this.title, required this.body, this.key = ''});

  final String title;
  final String body;
  final String key;

  factory GeneratedFact.fromJson(Map<String, dynamic> json) {
    return GeneratedFact(
      title: (json['title'] as String? ?? '').trim(),
      body: (json['body'] as String? ?? '').trim(),
      key: (json['key'] as String? ?? '').trim(),
    );
  }
}

class LearningFact {
  const LearningFact({
    required this.id,
    required this.topicId,
    required this.topicTitle,
    required this.title,
    required this.body,
    required this.language,
    required this.length,
    required this.createdAt,
    this.key = '',
  });

  final String id;
  final String topicId;
  final String topicTitle;
  final String title;
  final String body;
  final AppLanguage language;
  final NotificationLength length;
  final DateTime createdAt;
  final String key;

  factory LearningFact.fromJson(Map<String, dynamic> json) {
    return LearningFact(
      id: json['id'] as String,
      topicId: json['topicId'] as String,
      topicTitle: json['topicTitle'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      language: AppLanguage.fromCode(json['language'] as String?),
      length: NotificationLength.fromId(json['lengthMode'] as String?),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      key: (json['key'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'topicId': topicId,
    'topicTitle': topicTitle,
    'title': title,
    'body': body,
    'language': language.code,
    'lengthMode': length.id,
    'createdAt': createdAt.toIso8601String(),
    if (key.isNotEmpty) 'key': key,
  };
}
