import '../models/models.dart';
import 'answer_rules.dart';

class CardModeService {
  const CardModeService();

  /// Modes jouables pour une carte, déduits uniquement de ses données. Calculé
  /// à l'import et figé sur la carte : un mode n'est proposé que si la carte
  /// porte de quoi le jouer correctement.
  List<TestMode> allowedModesFor({
    required String? clozeText,
    List<String> clozeAnswers = const [],
    List<String> clozeWordBank = const [],
    required List<String> acceptedAnswers,
    List<String> wrongAnswers = const [],
  }) {
    final modes = <TestMode>[
      TestMode.multipleChoice,
      TestMode.classicFlashcard,
      TestMode.reversedFlashcard,
    ];

    if (clozeText != null &&
        clozeAnswers.isNotEmpty &&
        clozeWordBank.isNotEmpty &&
        validateStructuredCloze(
              clozeText: clozeText,
              clozeAnswers: clozeAnswers,
              clozeWordBank: clozeWordBank,
            ) ==
            null) {
      modes.add(TestMode.cloze);
    }

    if (acceptedAnswers.isNotEmpty) {
      modes.add(TestMode.freeText);
    }

    // Le vrai/faux tire au sort une affirmation parmi la bonne réponse et les
    // mauvaises : sans mauvaise réponse, l'affirmation serait toujours vraie.
    if (wrongAnswers.any((answer) => answer.trim().isNotEmpty)) {
      modes.add(TestMode.trueFalse);
    }

    return modes;
  }

  /// Mode à présenter la prochaine fois. [playedMode] est le mode réellement
  /// joué : il peut différer du mode stocké quand l'utilisateur impose un mode
  /// pour toute une session, et c'est bien la réponse donnée dans ce mode-là
  /// qui doit faire avancer la carte.
  TestMode nextMode(
    FlashcardRecord card,
    ReviewResult result, {
    TestMode? playedMode,
  }) {
    final allowed = card.allowedTestModes;
    if (allowed.isEmpty) {
      return TestMode.multipleChoice;
    }

    final current = playedMode ?? card.currentTestMode;
    int indexOf(TestMode mode) =>
        allowed.indexWhere((candidate) => candidate == mode);
    TestMode fallback(TestMode mode) =>
        allowed.contains(mode) ? mode : allowed.first;

    switch (result) {
      case ReviewResult.again:
        return fallback(TestMode.multipleChoice);
      case ReviewResult.hard:
        if (current == TestMode.multipleChoice &&
            allowed.contains(TestMode.classicFlashcard) &&
            card.repetitions >= 1) {
          return TestMode.classicFlashcard;
        }
        return fallback(current);
      case ReviewResult.good:
        final classicIndex = indexOf(TestMode.classicFlashcard);
        final reversedIndex = indexOf(TestMode.reversedFlashcard);
        if (current == TestMode.multipleChoice && classicIndex >= 0) {
          return TestMode.classicFlashcard;
        }
        if (current == TestMode.classicFlashcard &&
            reversedIndex >= 0 &&
            card.repetitions >= 2) {
          return TestMode.reversedFlashcard;
        }
        return fallback(current);
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

  List<TestMode> updatedModeHistory(
    FlashcardRecord card,
    TestMode nextMode, {
    TestMode? playedMode,
  }) {
    final current = playedMode ?? card.currentTestMode;
    return [...card.modeHistory, current, if (current != nextMode) nextMode];
  }
}
