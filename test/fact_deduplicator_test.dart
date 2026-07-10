import 'package:flutter_test/flutter_test.dart';
import 'package:unebil/models/app_language.dart';
import 'package:unebil/models/learning_fact.dart';
import 'package:unebil/models/notification_length.dart';
import 'package:unebil/services/fact_deduplicator.dart';

void main() {
  test('recognizes short and semantic paraphrases', () {
    expect(
      FactDeduplicator.areSimilar(
        const GeneratedFact(
          title: 'Octopus Hearts',
          body: 'Octopuses have three hearts.',
        ),
        const GeneratedFact(
          title: 'Three Hearts',
          body: 'An octopus has three hearts.',
        ),
      ),
      isTrue,
    );

    expect(
      FactDeduplicator.areSimilar(
        const GeneratedFact(
          title: "The Axolotl's Power",
          body:
              'Unlike most amphibians, axolotls regenerate limbs, heart tissue, and parts of their brain without permanent scars.',
        ),
        const GeneratedFact(
          title: "The Axolotl's Healing Power",
          body:
              'Unlike most animals, the axolotl can regenerate limbs, spinal cord segments, and parts of its heart and brain without scars.',
        ),
      ),
      isTrue,
    );
  });

  test('keeps distinct facts about the same animal', () {
    expect(
      FactDeduplicator.areSimilar(
        const GeneratedFact(
          title: 'Octopus Hearts',
          body: 'Octopuses have three hearts; two pump blood to the gills.',
        ),
        const GeneratedFact(
          title: 'Octopus Blue Blood',
          body:
              'Octopus blood uses copper-rich hemocyanin to carry oxygen in cold water.',
        ),
      ),
      isFalse,
    );
  });

  test('uses provider claim keys as an additional semantic guard', () {
    expect(
      FactDeduplicator.areSimilar(
        const GeneratedFact(
          key: 'octopus|three hearts',
          title: 'First wording',
          body: 'First body with little lexical overlap.',
        ),
        const GeneratedFact(
          key: 'octopus|three cardiac organs',
          title: 'Second wording',
          body: 'A completely different phrasing of the claim.',
        ),
      ),
      isTrue,
    );
  });

  test('does not trust a subject-only provider key', () {
    expect(
      FactDeduplicator.areSimilar(
        const GeneratedFact(
          key: 'octopus',
          title: 'Octopus Blue Blood',
          body: 'Copper-rich hemocyanin makes octopus blood appear blue.',
        ),
        const GeneratedFact(
          key: 'octopus',
          title: 'Distributed Intelligence',
          body: 'Most octopus neurons are located throughout its arms.',
        ),
      ),
      isFalse,
    );
  });

  test('recognizes legacy local placeholders in every app language', () {
    final bodies = <AppLanguage, String>{
      AppLanguage.en:
          'A useful idea about "Animals": choose one small question and test it today. Curiosity becomes knowledge through tiny daily steps.',
      AppLanguage.ru:
          'Идея про "Животные": выбери один маленький вопрос и проверь его сегодня. Так интерес превращается в знание без длинной учебы.',
      AppLanguage.kk:
          '"Жануарлар" туралы ой: бүгін бір шағын сұрақ таңдап, жауабын тексер. Қызығушылық осылай күн сайын білімге айналады.',
    };
    final titles = <AppLanguage, String>{
      AppLanguage.en: 'Animals: fact 1',
      AppLanguage.ru: 'Животные: факт 1',
      AppLanguage.kk: 'Жануарлар: дерек 1',
    };

    for (final language in AppLanguage.values) {
      expect(
        FactDeduplicator.isLegacyMock(
          LearningFact(
            id: language.code,
            topicId: 'animals',
            topicTitle: 'Animals',
            title: titles[language]!,
            body: bodies[language]!,
            language: language,
            length: NotificationLength.short,
            createdAt: DateTime.utc(2026, 7, 7),
          ),
        ),
        isTrue,
      );
    }
  });
}
