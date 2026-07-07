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

  test('generates against previous facts and skips duplicate responses',
      () async {
    const initialFact = GeneratedFact(
      title: 'Octopus Hearts',
      body:
          'Octopuses have three hearts: two pump blood to the gills, while the third circulates it to the rest of the body.',
    );
    const freshFact = GeneratedFact(
      title: 'Octopus Blue Blood',
      body:
          'Octopus blood uses copper-rich hemocyanin, which helps carry oxygen in cold, low-oxygen water and gives the blood a blue tint.',
    );
    final fakeGenerator = FakeFactGenerator(
      responses: <List<GeneratedFact>>[
        <GeneratedFact>[initialFact],
        <GeneratedFact>[initialFact, freshFact],
      ],
    );
    final controller = await createController(fakeGenerator: fakeGenerator);

    await controller.addTopic('Animals');
    final topicId = controller.topics.single.id;

    final addedCount = await controller.generateFactsForTopic(topicId, count: 2);

    expect(addedCount, 1);
    expect(fakeGenerator.lastExcludedFacts, hasLength(1));
    expect(fakeGenerator.lastExcludedFacts.single.title, initialFact.title);
    final facts = controller.factsForTopic(topicId);
    expect(facts, hasLength(2));
    expect(
      facts.where((fact) => fact.title == initialFact.title),
      hasLength(1),
    );
    expect(facts.first.title, freshFact.title);
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

  test('shows a test notification through scheduler', () async {
    final scheduler = RecordingScheduler();
    final controller = await createController(scheduler: scheduler);

    final delivered = await controller.showTestNotification();

    expect(delivered, isTrue);
    expect(scheduler.testNotificationCalls, 1);
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
  FakeFactGenerator({this.responses = const <List<GeneratedFact>>[]});

  final List<List<GeneratedFact>> responses;
  int calls = 0;
  List<GeneratedFact> lastExcludedFacts = const <GeneratedFact>[];

  @override
  Future<List<GeneratedFact>> generateFacts({
    required String topic,
    required AppLanguage language,
    required NotificationLength length,
    int count = 1,
    List<GeneratedFact> excludedFacts = const <GeneratedFact>[],
  }) async {
    calls += 1;
    lastExcludedFacts = excludedFacts;
    if (calls <= responses.length) {
      return responses[calls - 1];
    }

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
  int testNotificationCalls = 0;
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

  @override
  Future<void> showTestNotification({
    required AppSettings settings,
    required List<Topic> topics,
    required List<LearningFact> facts,
  }) async {
    testNotificationCalls += 1;
    lastSettings = settings;
    lastTopics = topics;
    lastFacts = facts;
  }
}
