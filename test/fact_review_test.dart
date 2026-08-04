import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unebil/models/app_language.dart';
import 'package:unebil/models/learning_fact.dart';
import 'package:unebil/models/notification_length.dart';
import 'package:unebil/models/topic.dart';
import 'package:unebil/services/app_controller.dart';
import 'package:unebil/services/fact_sort_service.dart';
import 'package:unebil/services/storage_service.dart';

import 'app_controller_test.dart';

void main() {
  test('migrates legacy facts as read without deleting stored data', () async {
    final createdAt = DateTime.utc(2026, 8, 1);
    final topic = Topic(
      id: 'space',
      title: 'Space',
      enabled: true,
      createdAt: createdAt,
    );
    final legacyFact = <String, dynamic>{
      'id': 'legacy-fact',
      'topicId': topic.id,
      'topicTitle': topic.title,
      'title': 'Legacy',
      'body': 'Stored before read tracking.',
      'language': 'en',
      'lengthMode': 'short',
      'createdAt': createdAt.toIso8601String(),
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      'unebil.topics': jsonEncode(<Object>[topic.toJson()]),
      'unebil.facts': jsonEncode(<Object>[legacyFact]),
    });
    final prefs = await SharedPreferences.getInstance();
    final controller = AppController(
      StorageService(prefs),
      FakeFactGenerator(),
      RecordingScheduler(),
    );

    await controller.load();

    expect(controller.facts.single.isRead, isTrue);
    expect(controller.facts.single.readAt, createdAt);
    final migratedJson =
        jsonDecode(prefs.getString('unebil.facts')!) as List<dynamic>;
    expect((migratedJson.single as Map<String, dynamic>)['readAt'], isNotNull);
  });

  test('persists read toggles, mark all, and self-assessment', () async {
    final controller = await createController();
    await controller.addTopic('Space');
    final topicId = controller.topics.single.id;
    final firstFact = controller.factsForTopic(topicId).single;

    expect(firstFact.isRead, isFalse);
    await controller.markFactRead(firstFact.id);
    expect(controller.facts.single.isRead, isTrue);
    await controller.markFactUnread(firstFact.id);
    expect(controller.facts.single.isRead, isFalse);
    await controller.markAllFactsRead(topicId);
    expect(controller.unreadCountForTopic(topicId), 0);

    await controller.saveFactReview(
      factId: firstFact.id,
      recallText: 'My recalled answer',
      result: ReviewResult.reviewAgain,
    );
    final reviewed = controller.facts.single;
    expect(reviewed.lastRecallText, 'My recalled answer');
    expect(reviewed.reviewResult, ReviewResult.reviewAgain);
    expect(reviewed.timesChecked, 1);
    expect(reviewed.lastCheckedAt, isNotNull);

    final prefs = await SharedPreferences.getInstance();
    final restored = AppController(
      StorageService(prefs),
      FakeFactGenerator(),
      RecordingScheduler(),
    );
    await restored.load();
    expect(restored.facts.single.reviewResult, ReviewResult.reviewAgain);
    expect(restored.facts.single.timesChecked, 1);
    expect(restored.facts.single.isRead, isTrue);
  });

  test('sorts unread, review-again, then other facts newest first', () {
    final now = DateTime.utc(2026, 8, 4);
    LearningFact fact(
      String id, {
      DateTime? readAt,
      ReviewResult? result,
      int age = 0,
    }) => LearningFact(
      id: id,
      topicId: 'topic',
      topicTitle: 'Topic',
      title: id,
      body: id,
      language: AppLanguage.en,
      length: NotificationLength.short,
      createdAt: now.subtract(Duration(days: age)),
      readAt: readAt,
      reviewResult: result,
    );

    final sorted = FactSortService.sortForReview(<LearningFact>[
      fact('read-new', readAt: now),
      fact('review-old', readAt: now, result: ReviewResult.reviewAgain, age: 2),
      fact('unread-old', age: 3),
      fact('review-new', readAt: now, result: ReviewResult.reviewAgain),
      fact('unread-new'),
    ]);

    expect(sorted.map((fact) => fact.id), <String>[
      'unread-new',
      'unread-old',
      'review-new',
      'review-old',
      'read-new',
    ]);
  });
}
