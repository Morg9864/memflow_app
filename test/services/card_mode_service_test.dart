import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/data/local/database.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/card_mode_service.dart';

void main() {
  const service = CardModeService();
  final now = DateTime(2026, 5, 29, 9, 0);

  Flashcard buildCard({
    TestMode currentMode = TestMode.multipleChoice,
    List<TestMode>? allowedModes,
    int repetitions = 0,
    String? clozeText,
    List<String> acceptedAnswers = const [],
  }) {
    return Flashcard(
      id: 'card-1',
      collectionId: 'react',
      deckId: 'deck-1',
      question: 'Question',
      correctAnswer: 'Réponse',
      answer: 'Réponse',
      wrongAnswers: const ['A', 'B', 'C'],
      hint: null,
      explanation: null,
      currentTestMode: currentMode,
      allowedTestModes: allowedModes ??
          service.allowedModesFor(
            clozeText: clozeText,
            acceptedAnswers: acceptedAnswers,
          ),
      lastTestMode: null,
      modeHistory: const [TestMode.multipleChoice],
      clozeText: clozeText,
      acceptedAnswers: acceptedAnswers,
      source: null,
      difficulty: DeckDifficulty.facile,
      level: 1,
      tags: const ['react'],
      dueAt: now,
      lastReviewedAt: null,
      intervalDays: 0,
      easeFactor: 2.5,
      repetitions: repetitions,
      lapses: 0,
      mastered: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('allowed modes include cloze and free text only when data exists', () {
    final modes = service.allowedModesFor(
      clozeText: 'React utilise {{useEffect}}.',
      acceptedAnswers: const ['useEffect'],
    );

    expect(modes, contains(TestMode.multipleChoice));
    expect(modes, contains(TestMode.cloze));
    expect(modes, contains(TestMode.freeText));
  });

  test('again always returns to multiple choice', () {
    final next = service.nextMode(
      buildCard(
        currentMode: TestMode.freeText,
        allowedModes: const [
          TestMode.multipleChoice,
          TestMode.classicFlashcard,
          TestMode.freeText,
        ],
      ),
      ReviewResult.again,
    );

    expect(next, TestMode.multipleChoice);
  });

  test('good promotes from multiple choice to classic flashcard', () {
    final next = service.nextMode(
      buildCard(repetitions: 1),
      ReviewResult.good,
    );

    expect(next, TestMode.classicFlashcard);
  });

  test('easy prefers the most active mode available', () {
    final next = service.nextMode(
      buildCard(
        currentMode: TestMode.classicFlashcard,
        repetitions: 3,
        clozeText: 'React utilise {{useEffect}}.',
        acceptedAnswers: const ['useEffect'],
      ),
      ReviewResult.easy,
    );

    expect(next, TestMode.freeText);
  });
}
