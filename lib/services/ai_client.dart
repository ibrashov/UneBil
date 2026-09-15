import 'dart:async';
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
    this.requestTimeout = const Duration(seconds: 70),
    this.startupTimeout = const Duration(seconds: 90),
    this.startupRetryDelay = const Duration(seconds: 2),
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://unebil.onrender.com',
    ),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final Duration requestTimeout;
  final Duration startupTimeout;
  final Duration startupRetryDelay;

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

    final normalizedBaseUrl = trimmedBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final backendUri = Uri.tryParse(normalizedBaseUrl);
    if (backendUri == null ||
        !['http', 'https'].contains(backendUri.scheme) ||
        backendUri.host.isEmpty ||
        backendUri.userInfo.isNotEmpty ||
        backendUri.hasQuery ||
        backendUri.hasFragment) {
      throw const FactGenerationException(
        'API_BASE_URL должен быть HTTP или HTTPS адресом backend.',
      );
    }

    try {
      final requestExclusions = excludedFacts.take(120).toList(growable: false);
      if (backendUri.host.endsWith('.onrender.com')) {
        await _waitForRender('$normalizedBaseUrl/health');
      }
      final uri = Uri.parse('$normalizedBaseUrl/api/generate-facts');
      final response = await _client
          .post(
            uri,
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, Object>{
              'topic': topic,
              'language': language.code,
              'lengthMode': length.id,
              'count': count,
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
          .timeout(requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorCode = _backendErrorCode(response.body);
        final details = _backendErrorDetails(response.body);
        final paymentRequired =
            response.statusCode == 402 ||
            errorCode == 'provider_payment_required' ||
            response.body.toLowerCase().contains('payment_required');
        if (paymentRequired) {
          throw const FactGenerationException(
            'У AI-провайдера недоступна оплаченная квота. Проверь баланс или подключи другой AI-провайдер.',
          );
        }
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

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
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
      final alreadyUsed = <GeneratedFact>[...excludedFacts];
      for (final fact in facts) {
        if (FactDeduplicator.containsDuplicate(fact, alreadyUsed)) {
          continue;
        }
        usableFacts.add(fact);
        alreadyUsed.add(fact);
      }

      if (usableFacts.isEmpty) {
        throw const FactGenerationException(
          'Backend вернул только уже известные факты.',
        );
      }
      return usableFacts.take(count).toList(growable: false);
    } on FactGenerationException {
      rethrow;
    } on TimeoutException {
      throw const FactGenerationException(
        'Backend не ответил вовремя. Подожди немного и попробуй снова.',
      );
    } on FormatException {
      throw const FactGenerationException(
        'Backend вернул ответ не в формате JSON-объекта. Проверь адрес API.',
      );
    } catch (_) {
      throw const FactGenerationException(
        'Backend недоступен. Запусти backend или проверь адрес API.',
      );
    }
  }

  Future<void> _waitForRender(String healthUrl) async {
    final timer = Stopwatch()..start();
    while (timer.elapsed < startupTimeout) {
      final remaining = startupTimeout - timer.elapsed;
      final response = await _client
          .get(Uri.parse(healthUrl))
          .timeout(remaining);
      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['ok'] == true) return;
        } on FormatException {
          // Render may return its HTML loading page while the service wakes.
        }
      } else if (![502, 503, 504].contains(response.statusCode)) {
        throw FactGenerationException(
          'Backend вернул ошибку ${response.statusCode} при проверке /health. Проверь адрес API.',
        );
      }
      final timeLeft = startupTimeout - timer.elapsed;
      if (timeLeft <= Duration.zero) break;
      await Future<void>.delayed(
        startupRetryDelay < timeLeft ? startupRetryDelay : timeLeft,
      );
    }
    throw TimeoutException('Render startup timed out');
  }

  String _backendErrorDetails(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final details = decoded['error'];
        return details is String ? details.trim() : '';
      }
    } catch (_) {
      return '';
    }
    return '';
  }

  String _backendErrorCode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final code = decoded['code'];
        return code is String ? code.trim() : '';
      }
    } catch (_) {
      return '';
    }
    return '';
  }
}
