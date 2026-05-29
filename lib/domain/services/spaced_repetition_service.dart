import '../../data/local/database.dart';
import '../models/models.dart';

class FlashcardReviewUpdate {
  const FlashcardReviewUpdate({
    required this.dueAt,
    required this.intervalDays,
    required this.easeFactor,
    required this.repetitions,
    required this.lapses,
    required this.mastered,
    required this.lastReviewedAt,
  });

  final DateTime dueAt;
  final double intervalDays;
  final double easeFactor;
  final int repetitions;
  final int lapses;
  final bool mastered;
  final DateTime lastReviewedAt;
}

class SpacedRepetitionService {
  const SpacedRepetitionService();

  FlashcardReviewUpdate applyReview(
    Flashcard card,
    ReviewResult result, {
    DateTime? now,
  }) {
    final reviewedAt = now ?? DateTime.now();
    var intervalDays = card.intervalDays;
    var easeFactor = card.easeFactor;
    var repetitions = card.repetitions;
    var lapses = card.lapses;
    var mastered = card.mastered;
    late DateTime dueAt;

    switch (result) {
      case ReviewResult.again:
        lapses += 1;
        repetitions = 0;
        intervalDays = 0;
        mastered = false;
        easeFactor = (easeFactor - 0.2).clamp(1.3, 3.0);
        dueAt = reviewedAt.add(const Duration(minutes: 10));
        break;
      case ReviewResult.hard:
        repetitions += 1;
        intervalDays = intervalDays <= 0 ? 1 : (intervalDays * 1.2).clamp(1, 365);
        easeFactor = (easeFactor - 0.08).clamp(1.3, 3.0);
        dueAt = reviewedAt.add(Duration(days: intervalDays.round()));
        break;
      case ReviewResult.good:
        repetitions += 1;
        if (repetitions == 1) {
          intervalDays = 1;
        } else if (repetitions == 2) {
          intervalDays = 3;
        } else {
          intervalDays = (intervalDays * easeFactor).clamp(1, 365);
        }
        dueAt = reviewedAt.add(Duration(days: intervalDays.round()));
        break;
      case ReviewResult.easy:
        repetitions += 1;
        easeFactor = (easeFactor + 0.12).clamp(1.3, 3.0);
        if (repetitions == 1) {
          intervalDays = 4;
        } else {
          intervalDays = (intervalDays * easeFactor * 1.4).clamp(2, 500);
        }
        mastered = repetitions >= 3 && easeFactor >= 2.6;
        dueAt = reviewedAt.add(Duration(days: intervalDays.round()));
        break;
    }

    return FlashcardReviewUpdate(
      dueAt: dueAt,
      intervalDays: intervalDays,
      easeFactor: easeFactor,
      repetitions: repetitions,
      lapses: lapses,
      mastered: mastered,
      lastReviewedAt: reviewedAt,
    );
  }
}
