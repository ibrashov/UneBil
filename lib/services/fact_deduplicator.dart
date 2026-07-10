import '../models/learning_fact.dart';

class FactCleanupResult {
  const FactCleanupResult({required this.facts, required this.changed});

  final List<LearningFact> facts;
  final bool changed;
}

class FactDeduplicator {
  const FactDeduplicator._();

  static const Set<String> _stopWords = <String>{
    // English
    'a', 'an', 'and', 'are', 'as', 'at', 'be', 'because', 'been', 'being',
    'by', 'can', 'do', 'does', 'for', 'from', 'had', 'has', 'have', 'in',
    'into', 'is', 'it', 'its', 'of', 'on', 'or', 'that', 'the', 'their',
    'this', 'through', 'to', 'was', 'were', 'which', 'while', 'with',
    // Russian
    'а', 'без', 'был', 'была', 'были', 'быть', 'в', 'во', 'для', 'до',
    'его', 'ее', 'её', 'и', 'из', 'или', 'их', 'как', 'к', 'на', 'не',
    'но', 'о', 'об', 'от', 'по', 'при', 'с', 'со', 'у', 'что', 'это',
    // Kazakh
    'ал', 'арқылы', 'бұл', 'бір', 'да', 'де', 'деп', 'және', 'үшін',
    'мен', 'пен', 'себебі', 'туралы', 'сияқты',
  };

  static const Map<String, String> _aliases = <String, String>{
    'cardiac': 'heart',
    'cardio': 'heart',
    'healing': 'regeneration',
    'heal': 'regeneration',
    'regenerate': 'regeneration',
    'regenerated': 'regeneration',
    'regenerating': 'regeneration',
    'regenerative': 'regeneration',
    'trio': 'three',
    'triple': 'three',
    'pair': 'two',
    'couple': 'two',
    'single': 'one',
    '1': 'one',
    '2': 'two',
    '3': 'three',
    '4': 'four',
    '5': 'five',
    '6': 'six',
    '7': 'seven',
    '8': 'eight',
    '9': 'nine',
    '10': 'ten',
  };

  static const Set<String> _numberTokens = <String>{
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
  };

  static bool containsDuplicate(
    GeneratedFact candidate,
    Iterable<GeneratedFact> existingFacts,
  ) {
    return existingFacts.any((existing) => areSimilar(candidate, existing));
  }

  static bool areSimilar(GeneratedFact first, GeneratedFact second) {
    final firstFingerprint = fingerprint(first.title, first.body);
    final secondFingerprint = fingerprint(second.title, second.body);
    if (firstFingerprint.isEmpty || secondFingerprint.isEmpty) {
      return false;
    }
    if (firstFingerprint == secondFingerprint) {
      return true;
    }

    final firstBody = normalize(first.body);
    final secondBody = normalize(second.body);
    if (firstBody.isNotEmpty && firstBody == secondBody) {
      return true;
    }

    final firstKeyTokens = _tokens(first.key);
    final secondKeyTokens = _tokens(second.key);
    final minimumKeySize = _minimum(
      firstKeyTokens.length,
      secondKeyTokens.length,
    );
    if (minimumKeySize >= 3 &&
        _containment(firstKeyTokens, secondKeyTokens) >= 0.8) {
      return true;
    }

    final firstTitleTokens = _tokens(first.title);
    final secondTitleTokens = _tokens(second.title);
    final firstBodyTokens = _tokens(first.body);
    final secondBodyTokens = _tokens(second.body);
    final firstAllTokens = <String>{...firstTitleTokens, ...firstBodyTokens};
    final secondAllTokens = <String>{...secondTitleTokens, ...secondBodyTokens};

    final bodyScore = _containment(firstBodyTokens, secondBodyTokens);
    final allScore = _containment(firstAllTokens, secondAllTokens);
    final titleScore = _containment(firstTitleTokens, secondTitleTokens);
    final minimumBodySize = _minimum(
      firstBodyTokens.length,
      secondBodyTokens.length,
    );
    final minimumAllSize = _minimum(
      firstAllTokens.length,
      secondAllTokens.length,
    );
    final minimumTitleSize = _minimum(
      firstTitleTokens.length,
      secondTitleTokens.length,
    );

    if (minimumBodySize >= 3 && bodyScore >= 0.78) {
      return true;
    }
    if (minimumAllSize >= 4 && allScore >= 0.76) {
      return true;
    }
    if (minimumTitleSize >= 2 &&
        titleScore >= 0.8 &&
        (bodyScore >= 0.4 || allScore >= 0.58)) {
      return true;
    }

    final sharedAllTokens = _intersectionSize(firstAllTokens, secondAllTokens);
    final sharedNumbers = _intersectionSize(
      firstAllTokens.where(_numberTokens.contains).toSet(),
      secondAllTokens.where(_numberTokens.contains).toSet(),
    );
    if (sharedAllTokens >= 3 &&
        sharedNumbers > 0 &&
        (titleScore >= 0.45 || bodyScore >= 0.3)) {
      return true;
    }

    return _characterNgramDice(firstBody, secondBody) >= 0.86;
  }

  static FactCleanupResult cleanStoredFacts(List<LearningFact> facts) {
    final kept = <LearningFact>[];
    var changed = false;

    for (final fact in facts) {
      if (isLegacyMock(fact)) {
        changed = true;
        continue;
      }

      final generated = GeneratedFact(
        title: fact.title,
        body: fact.body,
        key: fact.key,
      );
      final duplicate = kept.any(
        (existing) =>
            existing.topicId == fact.topicId &&
            existing.language == fact.language &&
            _areStorageDuplicates(
              generated,
              GeneratedFact(
                title: existing.title,
                body: existing.body,
                key: existing.key,
              ),
            ),
      );
      if (duplicate) {
        changed = true;
        continue;
      }
      kept.add(fact);
    }

    return FactCleanupResult(facts: kept, changed: changed);
  }

  static bool isLegacyMock(LearningFact fact) {
    final normalizedTitle = normalize(fact.title);
    final normalizedBody = normalize(fact.body);
    final numberedFallbackTitle = RegExp(
      r'(?:fact|факт|дерек)\s+\d+$',
      caseSensitive: false,
      unicode: true,
    ).hasMatch(normalizedTitle);
    if (!numberedFallbackTitle) {
      return false;
    }

    return normalizedBody.startsWith('mock ') ||
        normalizedBody.contains(
          'choose one small question and test it today',
        ) ||
        normalizedBody.contains(
          'ask one small question today and check the answer',
        ) ||
        normalizedBody.contains(
          'выбери один маленький вопрос и проверь его сегодня',
        ) ||
        normalizedBody.contains(
          'выбери один маленький вопрос и найди ответ сегодня',
        ) ||
        normalizedBody.contains(
          'бүгін бір шағын сұрақ таңдап жауабын тексер',
        ) ||
        normalizedBody.contains('бүгін бір сұрақ қойып нақты жауап ізде');
  }

  static bool _areStorageDuplicates(GeneratedFact first, GeneratedFact second) {
    // Cleanup is persisted, so it must be deliberately conservative. Semantic
    // similarity is used to block a new response, never to delete old data.
    final firstFingerprint = fingerprint(first.title, first.body);
    return (firstFingerprint.isNotEmpty &&
            firstFingerprint == fingerprint(second.title, second.body)) ||
        (normalize(first.body).isNotEmpty &&
            normalize(first.body) == normalize(second.body));
  }

  static String fingerprint(String title, String body) {
    return normalize('$title $body');
  }

  static String normalize(String value) {
    final withoutPossessives = value.toLowerCase().replaceAllMapped(
      RegExp(r"([a-z])['’]s\b", unicode: true),
      (match) => match.group(1)!,
    );
    return withoutPossessives
        .replaceAll(
          RegExp(
            r'[^a-z0-9а-яёәіңғүұқөһ]+',
            caseSensitive: false,
            unicode: true,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Set<String> _tokens(String value) {
    return normalize(value)
        .split(' ')
        .where((token) => token.isNotEmpty)
        .map(_canonicalToken)
        .where((token) => token.length > 1 && !_stopWords.contains(token))
        .toSet();
  }

  static String _canonicalToken(String rawToken) {
    final directAlias = _aliases[rawToken];
    if (directAlias != null) {
      return directAlias;
    }

    var token = rawToken;
    if (RegExp(r'^[a-z]+$').hasMatch(token)) {
      if (token.length > 5 && token.endsWith('ies')) {
        token = '${token.substring(0, token.length - 3)}y';
      } else if (token.length > 5 &&
          RegExp(r'(ches|shes|sses|uses|xes|zes)$').hasMatch(token)) {
        token = token.substring(0, token.length - 2);
      } else if (token.length > 4 &&
          token.endsWith('s') &&
          !token.endsWith('ss')) {
        token = token.substring(0, token.length - 1);
      }
    }
    return _aliases[token] ?? token;
  }

  static double _containment(Set<String> first, Set<String> second) {
    final minimumSize = _minimum(first.length, second.length);
    if (minimumSize == 0) {
      return 0;
    }
    return _intersectionSize(first, second) / minimumSize;
  }

  static int _intersectionSize(Set<String> first, Set<String> second) {
    final smallest = first.length <= second.length ? first : second;
    final largest = identical(smallest, first) ? second : first;
    return smallest.where(largest.contains).length;
  }

  static double _characterNgramDice(String first, String second) {
    if (first.length < 12 || second.length < 12) {
      return 0;
    }
    final firstNgrams = _ngrams(first, 3);
    final secondNgrams = _ngrams(second, 3);
    final denominator = firstNgrams.length + secondNgrams.length;
    if (denominator == 0) {
      return 0;
    }
    return 2 * _intersectionSize(firstNgrams, secondNgrams) / denominator;
  }

  static Set<String> _ngrams(String value, int size) {
    final result = <String>{};
    for (var index = 0; index <= value.length - size; index += 1) {
      result.add(value.substring(index, index + size));
    }
    return result;
  }

  static int _minimum(int first, int second) => first < second ? first : second;
}
