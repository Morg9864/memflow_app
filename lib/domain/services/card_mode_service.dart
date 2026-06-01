import '../models/models.dart';

class CardModeService {
  const CardModeService();

  List<TestMode> allowedModesFor({
    required String? clozeText,
    List<String> clozeAnswers = const [],
    List<String> clozeWordBank = const [],
    required List<String> acceptedAnswers,
    bool includeOptionalModes = false,
  }) {
    final modes = <TestMode>[
      TestMode.multipleChoice,
      TestMode.classicFlashcard,
      TestMode.reversedFlashcard,
    ];

    if (_supportsStructuredCloze(
      clozeText: clozeText,
      clozeAnswers: clozeAnswers,
      clozeWordBank: clozeWordBank,
    )) {
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

  bool _supportsStructuredCloze({
    required String? clozeText,
    required List<String> clozeAnswers,
    required List<String> clozeWordBank,
  }) {
    if (clozeText == null || clozeAnswers.isEmpty || clozeWordBank.isEmpty) {
      return false;
    }

    final holeCount = RegExp(r'\{\{([^}]+)\}\}').allMatches(clozeText).length;
    if (holeCount == 0 || holeCount != clozeAnswers.length) {
      return false;
    }

    return _containsRequiredWords(
      haystack: clozeWordBank,
      needles: clozeAnswers,
    );
  }

  bool _containsRequiredWords({
    required List<String> haystack,
    required List<String> needles,
  }) {
    final availableCounts = <String, int>{};
    for (final word in haystack) {
      final normalized = _normalize(word);
      availableCounts.update(
        normalized,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    for (final answer in needles) {
      final normalized = _normalize(answer);
      final count = availableCounts[normalized] ?? 0;
      if (count == 0) {
        return false;
      }
      availableCounts[normalized] = count - 1;
    }

    return true;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
