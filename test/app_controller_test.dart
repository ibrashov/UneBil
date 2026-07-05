import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unebil/models/app_language.dart';
import 'package:unebil/models/app_settings.dart';
import 'package:unebil/models/learning_fact.dart';
import 'package:unebil/models/notification_length.dart';
import 'package:unebil/models/notification_time.dart';
import 'package:unebil/models/topic.dart';
import 'package:unebil/services/app_controller.dart';
import 'package:unebil/services/fact_generator.dart';
import 'package:unebil/services/notification_scheduler.dart';
import 'package:unebil/services/storage_service.dart';

void main() {
  test('notification length modes map to expected word targets', () {
    expect(NotificationLength.short.targetWords, 20);
    expect(NotificationLength.medium.targetWords, 40);
    expect(NotificationLength.detailed.targetWords, 70);
  });

  test('adds, toggles, and deletes topics', () async {
    final fakeGenerator = FakeFactGenerator();
    final controller = await createController(fakeGenerator: fakeGenerator);

    await controller.addTopic('Космос');

    expect(controller.topics, hasLength(1));
    expect(controller.topics.single.title, 'Космос');
    expect(controller.topics.single.enabled, isTrue);
    expect(fakeGenerator.calls, 1);
    expect(controller.factsForTopic(controller.topics.single.id), hasLength(1));

    await controller.toggleTopic(controller.topics.single.id, false);
    expect(controller.topics.single.enabled, isFalse);

    await controller.deleteTopic(controller.topics.single.id);
    expect(controller.topics, isEmpty);
    expect(controller.facts, isEmpty);
  });

  test('saves and loads settings', () async {
    final prefs = await mockPrefs();
    final controller = AppController(
      StorageService(prefs),
      FakeFactGenerator(),
      RecordingScheduler(),
    );
    await controller.load();

    await controller.updateLanguage(AppLanguage.kk);
    await controller.updateLength(NotificationLength.detailed);
    await controller.addNotificationTime(
      const NotificationTime(hour: 18, minute: 30),
    );

    final loaded = StorageService(prefs).loadSettings();
    expect(loaded.language, AppLanguage.kk);
    expect(loaded.length, NotificationLength.detailed);
    expect(loaded.notificationTimes, contains(
      const NotificationTime(hour: 18, minute: 30),
    ));
  });
}

Future<SharedPreferences> mockPrefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return SharedPreferences.getInstance();
}

Future<AppController> createController({
  FakeFactGenerator? fakeGenerator,
  RecordingScheduler? scheduler,
}) async {
  final prefs = await mockPrefs();
  final controller = AppController(
    StorageService(prefs),
    fakeGenerator ?? FakeFactGenerator(),
    scheduler ?? RecordingScheduler(),
  );
  await controller.load();
  return controller;
}

class FakeFactGenerator implements FactGenerator {
  int calls = 0;

  @override
  Future<List<GeneratedFact>> generateFacts({
    required String topic,
    required AppLanguage language,
    required NotificationLength length,
    int count = 1,
  }) async {
    calls += 1;
    return List<GeneratedFact>.generate(
      count,
      (index) => GeneratedFact(
        title: '$topic fact ${index + 1}',
        body: 'Useful fact about $topic in ${language.code}.',
      ),
    );
  }
}

class RecordingScheduler implements FactNotificationScheduler {
  int scheduleCalls = 0;
  AppSettings? lastSettings;
  List<Topic>? lastTopics;
  List<LearningFact>? lastFacts;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleDailyFacts({
    required AppSettings settings,
    required List<Topic> topics,
    required List<LearningFact> facts,
  }) async {
    scheduleCalls += 1;
    lastSettings = settings;
    lastTopics = topics;
    lastFacts = facts;
  }
}
