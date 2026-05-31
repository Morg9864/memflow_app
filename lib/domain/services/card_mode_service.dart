import '../models/models.dart';

class CardModeService {
  const CardModeService();

  List<TestMode> allowedModesFor({
    required String? clozeText,
    required List<String> acceptedAnswers,
    bool includeOptionalModes = false,
  }) {
    final modes = <TestMode>[
      TestMode.multipleChoice,
      TestMode.classicFlashcard,
      TestMode.reversedFlashcard,
    ];

    if (clozeText != null &&
        clozeText.contains('{{') &&
        clozeText.contains('}}')) {
      modes.add(TestMode.cloze);
    }

    if (acceptedAnswers.isNotEmpty) {
      modes.add(TestMode.freeText);
    }

    if (includeOptionalModes) {
      modes.addAll(const [
        TestMode.trueFalse,
        TestMode.ordering,
        TestMode.matching,
      ]);
    }

    return modes;
  }

  TestMode nextMode(FlashcardRecord card, ReviewResult result) {
    final allowed = card.allowedTestModes;
    if (allowed.isEmpty) {
      return TestMode.multipleChoice;
    }

    int indexOf(TestMode mode) =>
        allowed.indexWhere((candidate) => candidate == mode);
    TestMode fallback(TestMode mode) =>
        allowed.contains(mode) ? mode : allowed.first;

    switch (result) {
      case ReviewResult.again:
        return fallback(TestMode.multipleChoice);
      case ReviewResult.hard:
        if (card.currentTestMode == TestMode.multipleChoice &&
            allowed.contains(TestMode.classicFlashcard) &&
            card.repetitions >= 1) {
          return TestMode.classicFlashcard;
        }
        return fallback(card.currentTestMode);
      case ReviewResult.good:
        final classicIndex = indexOf(TestMode.classicFlashcard);
        final reversedIndex = indexOf(TestMode.reversedFlashcard);
        if (card.currentTestMode == TestMode.multipleChoice &&
            classicIndex >= 0) {
          return TestMode.classicFlashcard;
        }
        if (card.currentTestMode == TestMode.classicFlashcard &&
            reversedIndex >= 0 &&
            card.repetitions >= 2) {
          return TestMode.reversedFlashcard;
        }
        return fallback(card.currentTestMode);
      case ReviewResult.easy:
        for (final preferred in const [
          TestMode.freeText,
          TestMode.cloze,
          TestMode.reversedFlashcard,
          TestMode.classicFlashcard,
        ]) {
          if (allowed.contains(preferred)) {
            return preferred;
          }
        }
        return allowed.first;
    }
  }

  List<TestMode> updatedModeHistory(FlashcardRecord card, TestMode nextMode) {
    return [
      ...card.modeHistory,
      card.currentTestMode,
      if (card.currentTestMode != nextMode) nextMode,
    ];
  }
}
