import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_language.dart';
import '../models/learning_fact.dart';
import '../models/notification_length.dart';
import 'fact_deduplicator.dart';
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
  final Map<String, List<GeneratedFact>> _factCache =
      <String, List<GeneratedFact>>{};

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

    final cacheKey =
        '${topic.trim().toLowerCase()}|${language.code}|${length.id}';
    final cachedFacts = _takeCachedFacts(cacheKey, count, excludedFacts);
    if (cachedFacts.length >= count) {
      return cachedFacts;
    }

    try {
      final neededCount = count - cachedFacts.length;
      // Cerebras currently allows only a few requests per minute. Fetching a
      // six-card reservoir once lets six rapid one-card taps stay local.
      final providerCount = neededCount < 6 ? 6 : neededCount;
      final requestExclusions = <GeneratedFact>[
        ...cachedFacts,
        ...excludedFacts,
      ].take(120).toList(growable: false);
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
              'count': providerCount,
              if (requestExclusions.isNotEmpty)
                'excludedFacts': requestExclusions
                    .map(
                      (fact) => <String, String>{
                        'title': fact.title,
                        'body': fact.body,
                        if (fact.key.isNotEmpty) 'key': fact.key,
                      },
                    )
                    .toList(),
            }),
          )
          .timeout(const Duration(seconds: 70));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final details = _backendErrorDetails(response.body);
        if (response.statusCode == 429) {
          throw const FactGenerationException(
            'Достигнут минутный лимит AI. Подожди около минуты и попробуй снова — заглушка вместо факта не будет сохранена.',
          );
        }
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

      final usableFacts = <GeneratedFact>[];
      final alreadyUsed = <GeneratedFact>[...excludedFacts, ...cachedFacts];
      for (final fact in facts) {
        if (FactDeduplicator.containsDuplicate(fact, alreadyUsed)) {
          continue;
        }
        usableFacts.add(fact);
        alreadyUsed.add(fact);
      }

      final result = <GeneratedFact>[
        ...cachedFacts,
        ...usableFacts.take(neededCount),
      ];
      final unusedFacts = usableFacts.skip(neededCount).toList(growable: false);
      if (unusedFacts.isNotEmpty) {
        _factCache[cacheKey] = unusedFacts;
      }
      if (result.isEmpty) {
        throw const FactGenerationException(
          'Backend вернул только уже известные факты.',
        );
      }
      return result;
    } on FactGenerationException {
      if (cachedFacts.isNotEmpty) {
        return cachedFacts;
      }
      rethrow;
    } catch (_) {
      if (cachedFacts.isNotEmpty) {
        return cachedFacts;
      }
      throw const FactGenerationException(
        'Backend недоступен. Запусти backend или проверь адрес API.',
      );
    }
  }

  List<GeneratedFact> _takeCachedFacts(
    String cacheKey,
    int count,
    List<GeneratedFact> excludedFacts,
  ) {
    final cached = _factCache.remove(cacheKey);
    if (cached == null || cached.isEmpty) {
      return <GeneratedFact>[];
    }

    final selected = <GeneratedFact>[];
    final remaining = <GeneratedFact>[];
    final alreadyUsed = <GeneratedFact>[...excludedFacts];
    for (final fact in cached) {
      if (FactDeduplicator.containsDuplicate(fact, alreadyUsed)) {
        continue;
      }
      if (selected.length < count) {
        selected.add(fact);
        alreadyUsed.add(fact);
      } else {
        remaining.add(fact);
      }
    }
    if (remaining.isNotEmpty) {
      _factCache[cacheKey] = remaining;
    }
    return selected;
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
