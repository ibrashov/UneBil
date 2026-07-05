import '../models/app_language.dart';
import '../models/learning_fact.dart';
import '../models/notification_length.dart';

abstract class FactGenerator {
  Future<List<GeneratedFact>> generateFacts({
    required String topic,
    required AppLanguage language,
    required NotificationLength length,
    int count = 1,
  });
}
