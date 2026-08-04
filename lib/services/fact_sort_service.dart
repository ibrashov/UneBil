import '../models/learning_fact.dart';

abstract final class FactSortService {
  static List<LearningFact> sortForReview(Iterable<LearningFact> facts) {
    final sorted = facts.toList(growable: false);
    sorted.sort((a, b) {
      final priorityComparison = _priority(a).compareTo(_priority(b));
      if (priorityComparison != 0) {
        return priorityComparison;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  static int _priority(LearningFact fact) {
    if (!fact.isRead) {
      return 0;
    }
    if (fact.reviewResult == ReviewResult.reviewAgain) {
      return 1;
    }
    return 2;
  }
}
