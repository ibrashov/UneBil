import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_language.dart';
import '../models/learning_fact.dart';
import '../models/notification_length.dart';
import 'fact_generator.dart';

class AiClient implements FactGenerator {
  AiClient({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:3000',
    ),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  @override
  Future<List<GeneratedFact>> generateFacts({
    required String topic,
    required AppLanguage language,
    required NotificationLength length,
    int count = 1,
  }) async {
    final trimmedBaseUrl = baseUrl.trim();
    if (trimmedBaseUrl.isEmpty) {
      return _mockFacts(topic, language, length, count);
    }

    try {
      final uri = Uri.parse(
        '${trimmedBaseUrl.replaceAll(RegExp(r'/$'), '')}/api/generate-facts',
      );
      final response = await _client
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object>{
              'topic': topic,
              'language': language.code,
              'lengthMode': length.id,
              'count': count,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _mockFacts(topic, language, length, count);
      }

      final decoded = jsonDecode(response.body);
      final rawFacts = decoded is Map<String, dynamic> ? decoded['facts'] : null;
      if (rawFacts is! List) {
        return _mockFacts(topic, language, length, count);
      }

      final facts = rawFacts
          .whereType<Map>()
          .map((item) => GeneratedFact.fromJson(Map<String, dynamic>.from(item)))
          .where((fact) => fact.title.isNotEmpty && fact.body.isNotEmpty)
          .toList();

      return facts.isEmpty ? _mockFacts(topic, language, length, count) : facts;
    } catch (_) {
      return _mockFacts(topic, language, length, count);
    }
  }

  List<GeneratedFact> _mockFacts(
    String topic,
    AppLanguage language,
    NotificationLength length,
    int count,
  ) {
    return List<GeneratedFact>.generate(count.clamp(1, 8), (index) {
      final number = index + 1;
      return switch (language) {
        AppLanguage.ru => GeneratedFact(
            title: '$topic: факт $number',
            body:
                'Идея про "$topic": выбери один маленький вопрос и проверь его сегодня. Так интерес превращается в знание без длинной учебы.',
          ),
        AppLanguage.kk => GeneratedFact(
            title: '$topic: дерек $number',
            body:
                '"$topic" туралы ой: бүгін бір шағын сұрақ таңдап, жауабын тексер. Қызығушылық осылай күн сайын білімге айналады.',
          ),
        AppLanguage.en => GeneratedFact(
            title: '$topic: fact $number',
            body:
                'A useful idea about "$topic": choose one small question and test it today. Curiosity becomes knowledge through tiny daily steps.',
          ),
      };
    });
  }
}
