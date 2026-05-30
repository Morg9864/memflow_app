import '../../data/repositories/app_repository.dart';
import '../../domain/models/models.dart';

class StudyController {
  StudyController(this._repository);

  final AppRepository _repository;

  Future<StudySessionState> load({
    String? collectionId,
    String? deckId,
    TestMode? forcedMode,
  }) {
    return _repository.startStudySession(
      collectionId: collectionId,
      deckId: deckId,
      forcedMode: forcedMode,
    );
  }

  bool evaluateMultipleChoice(StudyCard card, int selectedIndex, List<String> options) {
    if (selectedIndex < 0 || selectedIndex >= options.length) {
      return false;
    }
    return _normalize(options[selectedIndex]) == _normalize(card.correctAnswer);
  }

  bool evaluateFreeText(StudyCard card, String answer) {
    final normalizedAnswer = _normalize(answer);
    final accepted = card.acceptedAnswers.isEmpty
        ? [_normalize(card.correctAnswer)]
        : card.acceptedAnswers.map(_normalize);
    return accepted.contains(normalizedAnswer);
  }

  String buildClozePrompt(StudyCard card) {
    return (card.clozeText ?? card.question).replaceAllMapped(
      RegExp(r'\{\{([^}]+)\}\}'),
      (_) => '_____',
    );
  }

  bool evaluateCloze(StudyCard card, String answer) {
    final matches = RegExp(r'\{\{([^}]+)\}\}')
        .allMatches(card.clozeText ?? '')
        .map((match) => match.group(1)!)
        .toList();
    final accepted = <String>[
      ...matches,
      ...card.acceptedAnswers,
      card.correctAnswer,
    ].map(_normalize);
    return accepted.contains(_normalize(answer));
  }

  Future<void> submitReview({
    required String cardId,
    required ReviewResult result,
    required bool wasCorrect,
  }) {
    return _repository.submitReview(
      cardId: cardId,
      reviewResult: result,
      wasCorrect: wasCorrect,
    );
  }

  SessionSummary buildSummary(StudySessionState state) {
    return SessionSummary(
      collectionId: state.collectionId,
      deckId: state.deckId,
      deckTitle: state.deckTitle,
      totalCards: state.cards.length,
      reviewCounts: state.reviewCounts,
    );
  }

  ReviewResult suggestedResult(bool? wasCorrect) {
    if (wasCorrect == null) {
      return ReviewResult.good;
    }
    return wasCorrect ? ReviewResult.good : ReviewResult.again;
  }

  StudySessionState advance(StudySessionState state, ReviewResult result) {
    final updatedCounts = Map<ReviewResult, int>.from(state.reviewCounts)
      ..update(result, (value) => value + 1, ifAbsent: () => 1);
    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.cards.length) {
      return state.copyWith(
        reviewCounts: updatedCounts,
        isCompleted: true,
      );
    }

    return state.copyWith(
      currentIndex: nextIndex,
      revealed: false,
      clearSelectedOption: true,
      hasValidatedAnswer: false,
      freeTextAnswer: '',
      reviewCounts: updatedCounts,
      clearCorrectness: true,
      isCompleted: false,
    );
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
