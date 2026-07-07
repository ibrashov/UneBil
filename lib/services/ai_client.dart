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
    List<GeneratedFact> excludedFacts = const <GeneratedFact>[],
  }) async {
    final trimmedBaseUrl = baseUrl.trim();
    if (trimmedBaseUrl.isEmpty) {
      throw const FactGenerationException(
        'Не задан API_BASE_URL. Запусти приложение с адресом backend.',
      );
    }

    try {
      final uri = Uri.parse(
        '${trimmedBaseUrl.replaceAll(RegExp(r'/$'), '')}/api/generate-facts',
      );
      final response = await _client
          .post(
            uri,
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, Object>{
              'topic': topic,
              'language': language.code,
              'lengthMode': length.id,
              'count': count,
              if (excludedFacts.isNotEmpty)
                'excludedFacts': excludedFacts
                    .map(
                      (fact) => <String, String>{
                        'title': fact.title,
                        'body': fact.body,
                      },
                    )
                    .toList(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final details = _backendErrorDetails(response.body);
        throw FactGenerationException(
          details.isEmpty
              ? 'Backend вернул ошибку ${response.statusCode}.'
              : 'Backend вернул ошибку ${response.statusCode}: $details',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FactGenerationException(
          'Backend вернул ответ не в формате JSON-объекта.',
        );
      }

      if (decoded['source'] == 'mock') {
        throw const FactGenerationException(
          'Backend работает в mock-режиме: AI-ключ не загружен. Перезапусти backend из папки backend и проверь .env.',
        );
      }

      final rawFacts = decoded['facts'];
      if (rawFacts is! List) {
        throw const FactGenerationException(
          'Backend вернул ответ без списка фактов.',
        );
      }

      final facts = rawFacts
          .whereType<Map>()
          .map(
            (item) => GeneratedFact.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((fact) => fact.title.isNotEmpty && fact.body.isNotEmpty)
          .toList();

      if (facts.isEmpty) {
        throw const FactGenerationException(
          'Backend вернул пустой список фактов.',
        );
      }

      return facts;
    } on FactGenerationException {
      rethrow;
    } catch (_) {
      throw const FactGenerationException(
        'Backend недоступен. Запусти backend или проверь адрес API.',
      );
    }
  }

  String _backendErrorDetails(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final details = decoded['details'] ?? decoded['error'];
        return details is String ? details.trim() : '';
      }
    } catch (_) {
      return body.trim();
    }
    return '';
  }
}
