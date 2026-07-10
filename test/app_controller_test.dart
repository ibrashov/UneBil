import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unebil/models/app_language.dart';
import 'package:unebil/models/app_settings.dart';
import 'package:unebil/models/learning_fact.dart';
import 'package:unebil/models/notification_interval.dart';
import 'package:unebil/models/notification_length.dart';
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
    expect(controller.factsForTopic(controller.topics.single.id), hasLength(3));

    await controller.toggleTopic(controller.topics.single.id, false);
    expect(controller.topics.single.enabled, isFalse);

    await controller.deleteTopic(controller.topics.single.id);
    expect(controller.topics, isEmpty);
    expect(controller.facts, isEmpty);
  });

  test(
    'defaults legacy topics to a two-hour interval and persists an ID',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'unebil.topics': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'legacy-topic',
            'title': 'History',
            'enabled': true,
            'createdAt': DateTime.utc(2026, 7, 1).toIso8601String(),
          },
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = AppController(
        StorageService(prefs),
        FakeFactGenerator(),
        RecordingScheduler(),
      );

      await controller.load();

      final topic = controller.topics.single;
      expect(topic.notificationInterval, NotificationInterval.everyTwoHours);
      expect(topic.notificationId, greaterThanOrEqualTo(10000));
      final saved = StorageService(prefs).loadTopics().single;
      expect(saved.notificationInterval, NotificationInterval.everyTwoHours);
      expect(saved.notificationId, topic.notificationId);
    },
  );

  test('interval labels are available in every supported language', () {
    expect(NotificationInterval.hourly.label(AppLanguage.ru), 'Каждый час');
    expect(
      NotificationInterval.everyTwoHours.label(AppLanguage.kk),
      'Әр 2 сағат сайын',
    );
    expect(
      NotificationInterval.everyThreeHours.label(AppLanguage.en),
      'Every 3 hours',
    );
  });

  test('plans a bounded rotating queue from cached facts', () {
    final topic = Topic(
      id: 'space',
      title: 'Space',
      enabled: true,
      createdAt: DateTime.utc(2026, 7, 1),
      notificationInterval: NotificationInterval.hourly,
      notificationId: 12000,
    );
    final facts = <LearningFact>[
      LearningFact(
        id: 'first',
        topicId: topic.id,
        topicTitle: topic.title,
        title: 'First fact',
        body: 'First cached learning fact.',
        language: AppLanguage.en,
        length: NotificationLength.medium,
        createdAt: DateTime.utc(2026, 7, 1),
      ),
      LearningFact(
        id: 'second',
        topicId: topic.id,
        topicTitle: topic.title,
        title: 'Second fact',
        body: 'Second cached learning fact.',
        language: AppLanguage.en,
        length: NotificationLength.medium,
        createdAt: DateTime.utc(2026, 7, 2),
      ),
    ];

    final plan = buildIntervalNotificationPlan(
      settings: const AppSettings(
        language: AppLanguage.en,
        length: NotificationLength.medium,
      ),
      topics: <Topic>[topic],
      facts: facts,
      now: DateTime.utc(2026, 7, 10),
      notificationsPerTopic: 3,
    );

    expect(plan.map((item) => item.id), <int>[12000, 12001, 12002]);
    expect(
      plan[1].scheduledAt.difference(plan[0].scheduledAt),
      const Duration(hours: 1),
    );
    expect(plan[0].title, isNot(plan[1].title));
    expect(plan[0].title, plan[2].title);
  });

  test('generates against previous facts and skips duplicate responses', () async {
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

    final addedCount = await controller.generateFactsForTopic(
      topicId,
      count: 2,
    );

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

  test(
    'coalesces automatic and manual generation for the same topic',
    () async {
      final generator = BlockingFactGenerator();
      final controller = await createController(factGenerator: generator);

      final addFuture = controller.addTopic('Animals');
      for (
        var attempt = 0;
        attempt < 10 && generator.calls == 0;
        attempt += 1
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(generator.calls, 1);
      final topicId = controller.topics.single.id;
      expect(controller.isGeneratingTopic(topicId), isTrue);

      final manualFuture = controller.generateFactsForTopic(topicId);
      expect(generator.calls, 1);
      generator.complete(const <GeneratedFact>[
        GeneratedFact(
          key: 'octopus|blue blood',
          title: 'Octopus Blue Blood',
          body: 'Octopus blood is blue because it uses copper-rich hemocyanin.',
        ),
      ]);

      await addFuture;
      expect(await manualFuture, 1);
      expect(controller.factsForTopic(topicId), hasLength(1));
      expect(controller.isGeneratingTopic(topicId), isFalse);
    },
  );

  test(
    'keeps request language and length when settings change in flight',
    () async {
      final generator = DelayedSecondFactGenerator();
      final controller = await createController(factGenerator: generator);
      await controller.addTopic('Animals');
      final topicId = controller.topics.single.id;

      final generation = controller.generateFactsForTopic(topicId);
      await controller.updateLanguage(AppLanguage.kk);
      await controller.updateLength(NotificationLength.detailed);
      generator.completeSecond(const <GeneratedFact>[
        GeneratedFact(
          key: 'wombat|cube droppings',
          title: 'Wombat Cubes',
          body:
              'Wombats make cube-shaped droppings because their intestines stretch unevenly.',
        ),
      ]);

      expect(await generation, 1);
      final saved = controller.factsForTopic(topicId).first;
      expect(saved.language, AppLanguage.ru);
      expect(saved.length, NotificationLength.medium);
    },
  );

  test(
    'checks all stored facts instead of forgetting the oldest after 30',
    () async {
      const oldest = GeneratedFact(
        key: 'species0|property0',
        title: 'Oldest Fact',
        body: 'Specieszero',
      );
      final responses = <List<GeneratedFact>>[
        const <GeneratedFact>[oldest],
        for (var index = 1; index <= 30; index += 1)
          <GeneratedFact>[
            GeneratedFact(
              key: 'species$index|property$index',
              title: 'Fact$index',
              body: 'Species$index',
            ),
          ],
        const <GeneratedFact>[oldest],
      ];
      final generator = FakeFactGenerator(responses: responses);
      final controller = await createController(factGenerator: generator);
      await controller.addTopic('Animals');
      final topicId = controller.topics.single.id;
      for (var index = 0; index < 30; index += 1) {
        expect(await controller.generateFactsForTopic(topicId), 1);
      }

      expect(generator.lastExcludedFacts, hasLength(30));
      expect(await controller.generateFactsForTopic(topicId), 0);
      expect(generator.lastExcludedFacts, hasLength(31));
      expect(controller.factsForTopic(topicId), hasLength(31));
    },
  );

  test('six short generations reject a paraphrase of the first fact', () async {
    const first = GeneratedFact(
      key: 'octopus|three hearts',
      title: 'Octopus Hearts',
      body: 'Octopuses have three hearts; two pump blood to the gills.',
    );
    final generator = FakeFactGenerator(
      responses: const <List<GeneratedFact>>[
        <GeneratedFact>[first],
        <GeneratedFact>[
          GeneratedFact(
            key: 'axolotl|regeneration',
            title: 'Axolotl Regeneration',
            body: 'Axolotls can regrow limbs and spinal cord tissue.',
          ),
        ],
        <GeneratedFact>[
          GeneratedFact(
            key: 'mantis shrimp|vision',
            title: 'Mantis Shrimp Vision',
            body:
                'Mantis shrimp have many more color receptor types than humans.',
          ),
        ],
        <GeneratedFact>[
          GeneratedFact(
            key: 'wombat|cube droppings',
            title: 'Wombat Cubes',
            body: 'Wombat intestines shape droppings into cubes.',
          ),
        ],
        <GeneratedFact>[
          GeneratedFact(
            key: 'crow|tool use',
            title: 'Crow Tools',
            body: 'New Caledonian crows shape twigs into tools.',
          ),
        ],
        <GeneratedFact>[
          GeneratedFact(
            key: 'octopus|three cardiac organs',
            title: 'A Trio of Cardiac Organs',
            body:
                'An octopus has a trio of cardiac organs, including a pair for its gills.',
          ),
        ],
      ],
    );
    final controller = await createController(factGenerator: generator);
    await controller.addTopic('Animals');
    final topicId = controller.topics.single.id;
    for (var index = 0; index < 4; index += 1) {
      expect(await controller.generateFactsForTopic(topicId), 1);
    }

    expect(await controller.generateFactsForTopic(topicId), 0);
    expect(controller.factsForTopic(topicId), hasLength(5));
  });

  test(
    'load removes legacy fact 1 placeholders and exact stored duplicates',
    () async {
      final topic = Topic(
        id: 'animals',
        title: 'Animals',
        enabled: true,
        createdAt: DateTime.utc(2026, 7, 1),
      );
      final storedFacts = <LearningFact>[
        learningFact(
          id: 'mock',
          title: 'Animals: fact 1',
          body:
              'A useful idea about "Animals": choose one small question and test it today. Curiosity becomes knowledge through tiny daily steps.',
          createdAt: DateTime.utc(2026, 7, 4),
        ),
        learningFact(
          id: 'newest-duplicate',
          title: 'Three Hearts',
          body: 'An octopus has three hearts.',
          createdAt: DateTime.utc(2026, 7, 3),
        ),
        learningFact(
          id: 'older-duplicate',
          title: 'Octopus Hearts',
          body: '  AN OCTOPUS HAS THREE HEARTS. ',
          createdAt: DateTime.utc(2026, 7, 2),
        ),
        learningFact(
          id: 'fresh',
          title: 'Octopus Blue Blood',
          body: 'Octopus blood is blue because it uses copper-rich hemocyanin.',
          createdAt: DateTime.utc(2026, 7, 1),
          key: 'octopus',
        ),
        learningFact(
          id: 'also-fresh',
          title: 'Distributed Intelligence',
          body: 'Most octopus neurons are located throughout the arms.',
          createdAt: DateTime.utc(2026, 6, 30),
          key: 'octopus',
        ),
      ];
      SharedPreferences.setMockInitialValues(<String, Object>{
        'unebil.topics': jsonEncode(<Map<String, dynamic>>[topic.toJson()]),
        'unebil.facts': jsonEncode(
          storedFacts.map((fact) => fact.toJson()).toList(),
        ),
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = AppController(
        StorageService(prefs),
        FakeFactGenerator(),
        RecordingScheduler(),
      );

      await controller.load();

      expect(controller.facts, hasLength(3));
      expect(
        controller.facts.map((fact) => fact.id),
        containsAll(<String>['newest-duplicate', 'fresh', 'also-fresh']),
      );
      expect(StorageService(prefs).loadFacts(), hasLength(3));
    },
  );

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

    final loaded = StorageService(prefs).loadSettings();
    expect(loaded.language, AppLanguage.kk);
    expect(loaded.length, NotificationLength.detailed);
  });

  test(
    'changing a topic interval persists it and refreshes notifications',
    () async {
      final scheduler = RecordingScheduler();
      final controller = await createController(scheduler: scheduler);
      await controller.addTopic('Space', interval: NotificationInterval.hourly);
      final original = controller.topics.single;
      final scheduleCallsBeforeChange = scheduler.scheduleCalls;

      await controller.updateTopic(
        original.id,
        title: 'Space science',
        interval: NotificationInterval.everyThreeHours,
      );

      final updated = controller.topics.single;
      expect(updated.title, 'Space science');
      expect(
        updated.notificationInterval,
        NotificationInterval.everyThreeHours,
      );
      expect(updated.notificationId, original.notificationId);
      expect(scheduler.scheduleCalls, scheduleCallsBeforeChange + 1);
    },
  );

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
  FactGenerator? factGenerator,
  RecordingScheduler? scheduler,
}) async {
  final prefs = await mockPrefs();
  final controller = AppController(
    StorageService(prefs),
    factGenerator ?? fakeGenerator ?? FakeFactGenerator(),
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
  final List<List<GeneratedFact>> excludedFactsHistory =
      <List<GeneratedFact>>[];

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
    excludedFactsHistory.add(List<GeneratedFact>.of(excludedFacts));
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

class BlockingFactGenerator implements FactGenerator {
  final Completer<List<GeneratedFact>> _completer =
      Completer<List<GeneratedFact>>();
  int calls = 0;

  void complete(List<GeneratedFact> facts) => _completer.complete(facts);

  @override
  Future<List<GeneratedFact>> generateFacts({
    required String topic,
    required AppLanguage language,
    required NotificationLength length,
    int count = 1,
    List<GeneratedFact> excludedFacts = const <GeneratedFact>[],
  }) {
    calls += 1;
    return _completer.future;
  }
}

class DelayedSecondFactGenerator implements FactGenerator {
  final Completer<List<GeneratedFact>> _second =
      Completer<List<GeneratedFact>>();
  int calls = 0;

  void completeSecond(List<GeneratedFact> facts) => _second.complete(facts);

  @override
  Future<List<GeneratedFact>> generateFacts({
    required String topic,
    required AppLanguage language,
    required NotificationLength length,
    int count = 1,
    List<GeneratedFact> excludedFacts = const <GeneratedFact>[],
  }) {
    calls += 1;
    if (calls == 1) {
      return Future<List<GeneratedFact>>.value(const <GeneratedFact>[
        GeneratedFact(
          key: 'octopus|three hearts',
          title: 'Octopus Hearts',
          body: 'Octopuses have three hearts.',
        ),
      ]);
    }
    return _second.future;
  }
}

LearningFact learningFact({
  required String id,
  required String title,
  required String body,
  required DateTime createdAt,
  String key = '',
}) {
  return LearningFact(
    id: id,
    topicId: 'animals',
    topicTitle: 'Animals',
    title: title,
    body: body,
    language: AppLanguage.en,
    length: NotificationLength.short,
    createdAt: createdAt,
    key: key,
  );
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
  Future<void> scheduleFacts({
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
