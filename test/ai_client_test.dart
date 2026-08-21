import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unebil/models/app_language.dart';
import 'package:unebil/models/learning_fact.dart';
import 'package:unebil/models/notification_length.dart';
import 'package:unebil/services/ai_client.dart';
import 'package:unebil/services/fact_generator.dart';

void main() {
  test('fails clearly when API_BASE_URL is not configured', () async {
    var requestSent = false;
    final client = MockClient((_) async {
      requestSent = true;
      return http.Response('{}', 200);
    });
    final aiClient = AiClient(client: client, baseUrl: '  ');

    await expectLater(
      aiClient.generateFacts(
        topic: 'Animals',
        language: AppLanguage.en,
        length: NotificationLength.short,
      ),
      throwsA(
        isA<FactGenerationException>().having(
          (error) => error.message,
          'message',
          contains('API_BASE_URL'),
        ),
      ),
    );
    expect(requestSent, isFalse);
  });

  test(
    'sends the complete exclusion payload and parses the fact key',
    () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, Object>{
            'source': 'cerebras',
            'facts': <Map<String, String>>[
              <String, String>{
                'key': 'wombat|cube droppings',
                'title': 'Wombat Cubes',
                'body': 'Wombats produce cube-shaped droppings.',
              },
            ],
          }),
          200,
        );
      });
      final aiClient = AiClient(client: client, baseUrl: 'http://backend.test');

      final result = await aiClient.generateFacts(
        topic: 'Animals',
        language: AppLanguage.en,
        length: NotificationLength.short,
        excludedFacts: const <GeneratedFact>[
          GeneratedFact(
            key: 'octopus|three hearts',
            title: 'Octopus Hearts',
            body: 'Octopuses have three hearts.',
          ),
        ],
      );

      expect(capturedBody?['topic'], 'Animals');
      final exclusions = capturedBody?['excludedFacts'] as List<dynamic>;
      expect(exclusions, hasLength(1));
      expect(
        (exclusions.single as Map<String, dynamic>)['key'],
        'octopus|three hearts',
      );
      expect(result.single.key, 'wombat|cube droppings');
    },
  );

  test('never turns an explicit backend mock into a saved fact', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode(<String, Object>{
          'source': 'mock',
          'facts': <Map<String, String>>[
            <String, String>{
              'title': 'Animals: fact 1',
              'body': 'A placeholder, not a real fact.',
            },
          ],
        }),
        200,
      ),
    );
    final aiClient = AiClient(client: client, baseUrl: 'http://backend.test');

    expect(
      () => aiClient.generateFacts(
        topic: 'Animals',
        language: AppLanguage.en,
        length: NotificationLength.short,
      ),
      throwsA(
        isA<FactGenerationException>().having(
          (error) => error.message,
          'message',
          contains('mock'),
        ),
      ),
    );
  });

  test('reports a rate limit instead of generating fact 1 fallback', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode(<String, String>{'error': 'AI provider rate limit reached'}),
        429,
      ),
    );
    final aiClient = AiClient(client: client, baseUrl: 'http://backend.test');

    expect(
      () => aiClient.generateFacts(
        topic: 'Animals',
        language: AppLanguage.en,
        length: NotificationLength.short,
      ),
      throwsA(
        isA<FactGenerationException>().having(
          (error) => error.message,
          'message',
          allOf(contains('лимит'), isNot(contains('fact 1'))),
        ),
      ),
    );
  });

  test('reports provider payment failure without exposing raw JSON', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode(<String, String>{
          'error': 'AI provider billing or quota is unavailable',
          'code': 'provider_payment_required',
        }),
        402,
      ),
    );
    final aiClient = AiClient(client: client, baseUrl: 'http://backend.test');

    expect(
      () => aiClient.generateFacts(
        topic: 'Animals',
        language: AppLanguage.en,
        length: NotificationLength.short,
      ),
      throwsA(
        isA<FactGenerationException>().having(
          (error) => error.message,
          'message',
          allOf(contains('оплаченная квота'), isNot(contains('{'))),
        ),
      ),
    );
  });

  test(
    'recognizes payment failure from an older backend 502 response',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode(<String, String>{
            'error': 'AI provider failed to generate facts',
            'details': 'cerebras HTTP 402: {"code":"payment_required"}',
          }),
          502,
        ),
      );
      final aiClient = AiClient(client: client, baseUrl: 'http://backend.test');

      expect(
        () => aiClient.generateFacts(
          topic: 'Animals',
          language: AppLanguage.en,
          length: NotificationLength.short,
        ),
        throwsA(
          isA<FactGenerationException>().having(
            (error) => error.message,
            'message',
            allOf(contains('оплаченная квота'), isNot(contains('HTTP 402'))),
          ),
        ),
      );
    },
  );

  test(
    'does not expose backend diagnostic details for generic failures',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode(<String, String>{
            'error': 'AI provider failed to generate facts',
            'details': 'private provider diagnostic',
          }),
          502,
        ),
      );
      final aiClient = AiClient(client: client, baseUrl: 'http://backend.test');

      expect(
        () => aiClient.generateFacts(
          topic: 'Animals',
          language: AppLanguage.en,
          length: NotificationLength.short,
        ),
        throwsA(
          isA<FactGenerationException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('AI provider failed to generate facts'),
              isNot(contains('private provider diagnostic')),
            ),
          ),
        ),
      );
    },
  );

  test('requests and returns one complete 10-fact backend batch', () async {
    var httpCalls = 0;
    int? requestedCount;
    final client = MockClient((request) async {
      httpCalls += 1;
      requestedCount =
          (jsonDecode(request.body) as Map<String, dynamic>)['count'] as int;
      return http.Response(
        jsonEncode(<String, Object>{
          'source': 'cerebras',
          'facts': _backendBatch(factGenerationBatchSize),
        }),
        200,
      );
    });
    final aiClient = AiClient(client: client, baseUrl: 'http://backend.test');

    final generated = await aiClient.generateFacts(
      topic: 'Space',
      language: AppLanguage.en,
      length: NotificationLength.short,
      count: factGenerationBatchSize,
    );

    expect(requestedCount, factGenerationBatchSize);
    expect(httpCalls, 1);
    expect(generated, hasLength(factGenerationBatchSize));
  });

  test(
    'accepts a partial backend batch without making a refill call',
    () async {
      var httpCalls = 0;
      final client = MockClient((_) async {
        httpCalls += 1;
        return http.Response(
          jsonEncode(<String, Object>{
            'source': 'cerebras',
            'facts': _backendBatch(factGenerationBatchSize - 1),
          }),
          200,
        );
      });
      final aiClient = AiClient(client: client, baseUrl: 'http://backend.test');

      final partial = await aiClient.generateFacts(
        topic: 'Flutter & Dart',
        language: AppLanguage.en,
        length: NotificationLength.short,
        count: factGenerationBatchSize,
      );

      expect(httpCalls, 1);
      expect(partial, hasLength(factGenerationBatchSize - 1));
    },
  );
}

List<Map<String, String>> _backendBatch(int count) {
  const facts = <Map<String, String>>[
    <String, String>{
      'key': 'mercury|year',
      'title': 'Mercury Year',
      'body': 'Mercury completes an orbit in only 88 Earth days.',
    },
    <String, String>{
      'key': 'venus|rotation',
      'title': 'Venus Rotation',
      'body': 'Venus rotates slower than it travels around the Sun.',
    },
    <String, String>{
      'key': 'earth|tectonics',
      'title': 'Moving Plates',
      'body': 'Earth recycles crust through plate tectonics and subduction.',
    },
    <String, String>{
      'key': 'mars|volcano',
      'title': 'Olympus Mons',
      'body': 'Mars hosts the tallest known volcano in the Solar System.',
    },
    <String, String>{
      'key': 'jupiter|magnetism',
      'title': 'Jupiter Magnetism',
      'body': 'Jupiter has an exceptionally powerful planetary magnetic field.',
    },
    <String, String>{
      'key': 'saturn|density',
      'title': 'Saturn Density',
      'body': 'Saturn has a lower average density than liquid water.',
    },
    <String, String>{
      'key': 'uranus|tilt',
      'title': 'Sideways Uranus',
      'body': 'Uranus spins with an axial tilt of about 98 degrees.',
    },
    <String, String>{
      'key': 'neptune|winds',
      'title': 'Neptune Winds',
      'body': 'Neptune winds can exceed two thousand kilometers per hour.',
    },
    <String, String>{
      'key': 'moon|recession',
      'title': 'Receding Moon',
      'body': 'The Moon moves several centimeters away from Earth yearly.',
    },
    <String, String>{
      'key': 'sun|mass',
      'title': 'Solar Mass',
      'body': 'The Sun holds nearly all mass in our planetary system.',
    },
    <String, String>{
      'key': 'black hole|time',
      'title': 'Gravity and Time',
      'body': 'Extreme gravity makes nearby clocks appear to run slower.',
    },
    <String, String>{
      'key': 'pulsar|rotation',
      'title': 'Pulsar Clocks',
      'body': 'Some pulsars spin hundreds of times during one second.',
    },
    <String, String>{
      'key': 'comet|tail',
      'title': 'Comet Tails',
      'body': 'Solar radiation pushes a comet tail away from the Sun.',
    },
    <String, String>{
      'key': 'nebula|stars',
      'title': 'Stellar Nurseries',
      'body': 'Dense nebula regions can collapse and create new stars.',
    },
    <String, String>{
      'key': 'exoplanet|transit',
      'title': 'Transit Detection',
      'body': 'Tiny periodic starlight dips can reveal orbiting exoplanets.',
    },
  ];
  return facts.take(count).toList(growable: false);
}
