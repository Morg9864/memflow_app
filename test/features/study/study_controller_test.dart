import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/features/study/study_controller.dart';

void main() {
  StudyCard buildCard(String id) {
    return StudyCard(
      id: id,
      collectionId: 'react',
      deckId: 'deck-1',
      question: 'Question $id',
      correctAnswer: 'Réponse $id',
      wrongAnswers: const ['A', 'B', 'C'],
      hint: null,
      explanation: null,
      currentTestMode: TestMode.multipleChoice,
      allowedTestModes: const [
        TestMode.multipleChoice,
        TestMode.classicFlashcard,
      ],
      clozeText: null,
      acceptedAnswers: const [],
      level: 1,
      progressDots: 3,
    );
  }

  StudySessionState buildState(List<StudyCard> cards) {
    return StudySessionState(
      deckTitle: 'React',
      collectionId: 'react',
      deckId: 'deck-1',
      cards: cards,
      sessionCardIds: cards.map((card) => card.id).toSet(),
      seenCardIds: const <String>{},
      pendingReviewResults: const <String, ReviewResult>{},
      currentIndex: 0,
      revealed: false,
      selectedOptionIndex: null,
      hasValidatedAnswer: false,
      freeTextAnswer: '',
      reviewCounts: const {
        ReviewResult.again: 0,
        ReviewResult.hard: 0,
        ReviewResult.good: 0,
        ReviewResult.easy: 0,
      },
      currentAnswerWasCorrect: null,
      isCompleted: false,
    );
  }

  test('phase 1 keeps a fixed order before replaying pending cards', () {
    final controller = StudyController.forTesting(random: math.Random(0));
    final initialState = buildState([
      buildCard('a'),
      buildCard('b'),
      buildCard('c'),
    ]);

    final nextState = controller.advance(initialState, ReviewResult.hard);

    expect(nextState.currentCard.id, 'b');
    expect(nextState.cards.map((card) => card.id).toList(), [
      'a',
      'b',
      'c',
      'a',
    ]);
    expect(nextState.seenCardIds, {'a'});
    expect(nextState.pendingReviewResults, {'a': ReviewResult.hard});
  });

  test(
    'phase 2 reorders pending cards with again before hard and completes',
    () {
      final controller = StudyController.forTesting(random: math.Random(0));
      final initialState = buildState([
        buildCard('a'),
        buildCard('b'),
        buildCard('c'),
      ]);

      final afterA = controller.advance(initialState, ReviewResult.hard);
      final afterB = controller.advance(afterA, ReviewResult.good);
      final afterC = controller.advance(afterB, ReviewResult.again);

      expect(afterC.currentCard.id, 'c');
      expect(afterC.cards.map((card) => card.id).toList(), [
        'a',
        'b',
        'c',
        'c',
        'a',
      ]);
      expect(afterC.pendingReviewResults, {
        'a': ReviewResult.hard,
        'c': ReviewResult.again,
      });

      final afterRetryC = controller.advance(afterC, ReviewResult.good);
      expect(afterRetryC.currentCard.id, 'a');
      expect(afterRetryC.pendingReviewResults, {'a': ReviewResult.hard});

      final completed = controller.advance(afterRetryC, ReviewResult.easy);
      expect(completed.isCompleted, isTrue);
      expect(completed.pendingReviewResults, isEmpty);
    },
  );
}
