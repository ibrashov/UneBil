import '../models/app_language.dart';
import '../models/learning_fact.dart';
import '../models/notification_length.dart';

class FactGenerationException implements Exception {
  const FactGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class FactGenerator {
  Future<List<GeneratedFact>> generateFacts({
    required String topic,
    required AppLanguage language,
    required NotificationLength length,
    int count = 1,
    List<GeneratedFact> excludedFacts = const <GeneratedFact>[],
  });
}
