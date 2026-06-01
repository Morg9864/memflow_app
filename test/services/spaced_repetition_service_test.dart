import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/spaced_repetition_service.dart';

void main() {
  const service = SpacedRepetitionService();
  final baseNow = DateTime(2026, 5, 29, 9, 0);

  FlashcardRecord buildCard({
    int repetitions = 0,
    double intervalDays = 0,
    double easeFactor = 2.5,
    int lapses = 0,
    bool mastered = false,
  }) {
    return FlashcardRecord(
      id: 'card-1',
      collectionId: 'react',
      deckId: 'deck-1',
      question: 'Question',
      correctAnswer: 'Réponse',
      answer: 'Réponse',
      wrongAnswers: const ['A', 'B', 'C'],
      hint: null,
      explanation: null,
      currentTestMode: TestMode.multipleChoice,
      allowedTestModes: const [
        TestMode.multipleChoice,
        TestMode.classicFlashcard,
      ],
      lastTestMode: null,
      modeHistory: const [TestMode.multipleChoice],
      clozeText: null,
      clozeAnswers: const [],
      clozeWordBank: const [],
      acceptedAnswers: const ['Réponse'],
      source: null,
      difficulty: DeckDifficulty.facile,
      level: 1,
      tags: const ['react'],
      dueAt: baseNow,
      lastReviewedAt: null,
      intervalDays: intervalDays,
      easeFactor: easeFactor,
      repetitions: repetitions,
      lapses: lapses,
      mastered: mastered,
      createdAt: baseNow,
      updatedAt: baseNow,
    );
  }

  test('again resets repetitions and schedules card in 5 minutes', () {
    final update = service.applyReview(
      buildCard(repetitions: 3, intervalDays: 5, lapses: 1, mastered: true),
      ReviewResult.again,
      now: baseNow,
    );

    expect(update.repetitions, 0);
    expect(update.lapses, 2);
    expect(update.intervalDays, 0);
    expect(update.mastered, isFalse);
    expect(update.dueAt, baseNow.add(const Duration(minutes: 5)));
  });

  test('hard keeps interval data but schedules card in 15 minutes', () {
    final update = service.applyReview(
      buildCard(repetitions: 2, intervalDays: 5, easeFactor: 2.6),
      ReviewResult.hard,
      now: baseNow,
    );

    expect(update.repetitions, 3);
    expect(update.intervalDays, 6);
    expect(update.easeFactor, closeTo(2.52, 0.001));
    expect(update.dueAt, baseNow.add(const Duration(minutes: 15)));
  });

  test('good uses 1 day for first success and 3 days for second success', () {
    final first = service.applyReview(
      buildCard(repetitions: 0, intervalDays: 0),
      ReviewResult.good,
      now: baseNow,
    );
    final second = service.applyReview(
      buildCard(repetitions: 1, intervalDays: 1),
      ReviewResult.good,
      now: baseNow,
    );

    expect(first.intervalDays, 1);
    expect(first.dueAt, baseNow.add(const Duration(days: 1)));
    expect(second.intervalDays, 3);
    expect(second.dueAt, baseNow.add(const Duration(days: 3)));
  });

  test(
    'easy promotes mastery when repetitions and ease factor are high enough',
    () {
      final update = service.applyReview(
        buildCard(repetitions: 2, intervalDays: 6, easeFactor: 2.55),
        ReviewResult.easy,
        now: baseNow,
      );

      expect(update.repetitions, 3);
      expect(update.mastered, isTrue);
      expect(update.easeFactor, greaterThan(2.6));
      expect(update.intervalDays, greaterThan(6));
    },
  );

  test('good interval is capped to avoid excessive jumps', () {
    final update = service.applyReview(
      buildCard(repetitions: 6, intervalDays: 90, easeFactor: 2.8),
      ReviewResult.good,
      now: baseNow,
    );

    expect(update.intervalDays, 120);
    expect(update.dueAt, baseNow.add(const Duration(days: 120)));
  });

  test('easy interval is capped to avoid year-long scheduling jumps', () {
    final update = service.applyReview(
      buildCard(repetitions: 6, intervalDays: 120, easeFactor: 2.8),
      ReviewResult.easy,
      now: baseNow,
    );

    expect(update.intervalDays, 180);
    expect(update.dueAt, baseNow.add(const Duration(days: 180)));
  });
}
