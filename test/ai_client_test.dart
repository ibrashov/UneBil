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

  test(
    'serves six rapid one-card generations from one prefetched batch',
    () async {
      var httpCalls = 0;
      int? requestedCount;
      final client = MockClient((request) async {
        httpCalls += 1;
        requestedCount =
            (jsonDecode(request.body) as Map<String, dynamic>)['count'] as int;
        return http.Response(
          jsonEncode(<String, Object>{
            'source': 'cerebras',
            'facts': const <Map<String, String>>[
              <String, String>{
                'key': 'axolotl|regeneration',
                'title': 'Axolotl Regeneration',
                'body': 'Axolotls can regrow limbs and spinal cord tissue.',
              },
              <String, String>{
                'key': 'wombat|cube droppings',
                'title': 'Wombat Cubes',
                'body': 'Wombat intestines shape droppings into cubes.',
              },
              <String, String>{
                'key': 'crow|tool use',
                'title': 'Crow Tools',
                'body': 'New Caledonian crows shape twigs into tools.',
              },
              <String, String>{
                'key': 'mantis shrimp|vision',
                'title': 'Mantis Shrimp Vision',
                'body':
                    'Mantis shrimp have unusually many color receptor types.',
              },
              <String, String>{
                'key': 'platypus|electroreception',
                'title': 'Platypus Hunting',
                'body':
                    'Platypuses detect electrical signals made by moving prey.',
              },
              <String, String>{
                'key': 'sea otter|stone tools',
                'title': 'Sea Otter Tools',
                'body': 'Sea otters use stones to crack hard-shelled prey.',
              },
            ],
          }),
          200,
        );
      });
      final aiClient = AiClient(client: client, baseUrl: 'http://backend.test');

      final generated = <GeneratedFact>[];
      for (var index = 0; index < 6; index += 1) {
        final next = await aiClient.generateFacts(
          topic: 'Animals',
          language: AppLanguage.en,
          length: NotificationLength.short,
          excludedFacts: generated,
        );
        generated.addAll(next);
      }

      expect(requestedCount, 6);
      expect(httpCalls, 1);
      expect(<String>{...generated.map((fact) => fact.key)}, hasLength(6));
    },
  );

  test('returns a partial cache when its refill is rate-limited', () async {
    var httpCalls = 0;
    final client = MockClient((_) async {
      httpCalls += 1;
      if (httpCalls == 1) {
        return http.Response(
          jsonEncode(<String, Object>{
            'source': 'cerebras',
            'facts': const <Map<String, String>>[
              <String, String>{
                'key': 'axolotl|limb regeneration',
                'title': 'Axolotl Regeneration',
                'body': 'Axolotls can regrow limbs and spinal cord tissue.',
              },
              <String, String>{
                'key': 'wombat|cube droppings',
                'title': 'Wombat Cubes',
                'body': 'Wombat intestines shape droppings into cubes.',
              },
            ],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode(<String, String>{'error': 'rate limit'}),
        429,
      );
    });
    final aiClient = AiClient(client: client, baseUrl: 'http://backend.test');

    final first = await aiClient.generateFacts(
      topic: 'Animals',
      language: AppLanguage.en,
      length: NotificationLength.short,
    );
    final partial = await aiClient.generateFacts(
      topic: 'Animals',
      language: AppLanguage.en,
      length: NotificationLength.short,
      count: 2,
      excludedFacts: first,
    );

    expect(httpCalls, 2);
    expect(partial, hasLength(1));
    expect(partial.single.key, 'wombat|cube droppings');
  });
}
