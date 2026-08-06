import 'app_language.dart';
import 'notification_length.dart';

enum ReviewResult {
  remembered,
  reviewAgain;

  static ReviewResult? fromId(String? id) {
    return ReviewResult.values.where((value) => value.name == id).firstOrNull;
  }
}

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
    this.readAt,
    this.lastCheckedAt,
    this.lastRecallText = '',
    this.reviewResult,
    this.timesChecked = 0,
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
  final DateTime? readAt;
  final DateTime? lastCheckedAt;
  final String lastRecallText;
  final ReviewResult? reviewResult;
  final int timesChecked;

  bool get isRead => readAt != null;

  factory LearningFact.fromJson(Map<String, dynamic> json) {
    // Migration: facts saved before read tracking existed are considered read.
    // Explicit `readAt: null` is retained as the new unread state.
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    final readAt = json.containsKey('readAt')
        ? DateTime.tryParse(json['readAt'] as String? ?? '')
        : createdAt;
    return LearningFact(
      id: json['id'] as String,
      topicId: json['topicId'] as String,
      topicTitle: json['topicTitle'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      language: AppLanguage.fromCode(json['language'] as String?),
      length: NotificationLength.fromId(json['lengthMode'] as String?),
      createdAt: createdAt,
      key: (json['key'] as String? ?? '').trim(),
      readAt: readAt,
      lastCheckedAt: DateTime.tryParse(json['lastCheckedAt'] as String? ?? ''),
      lastRecallText: json['lastRecallText'] as String? ?? '',
      reviewResult: ReviewResult.fromId(json['reviewResult'] as String?),
      timesChecked: (json['timesChecked'] as num?)?.toInt() ?? 0,
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
    'readAt': readAt?.toIso8601String(),
    if (lastCheckedAt != null)
      'lastCheckedAt': lastCheckedAt!.toIso8601String(),
    if (lastRecallText.isNotEmpty) 'lastRecallText': lastRecallText,
    if (reviewResult != null) 'reviewResult': reviewResult!.name,
    'timesChecked': timesChecked,
  };

  LearningFact copyWith({
    String? topicTitle,
    DateTime? readAt,
    bool clearReadAt = false,
    DateTime? lastCheckedAt,
    String? lastRecallText,
    ReviewResult? reviewResult,
    int? timesChecked,
  }) {
    return LearningFact(
      id: id,
      topicId: topicId,
      topicTitle: topicTitle ?? this.topicTitle,
      title: title,
      body: body,
      language: language,
      length: length,
      createdAt: createdAt,
      key: key,
      readAt: clearReadAt ? null : readAt ?? this.readAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      lastRecallText: lastRecallText ?? this.lastRecallText,
      reviewResult: reviewResult ?? this.reviewResult,
      timesChecked: timesChecked ?? this.timesChecked,
    );
  }
}
