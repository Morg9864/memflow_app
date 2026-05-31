import 'dart:math' as math;

import '../../data/repositories/app_repository.dart';
import '../../domain/models/models.dart';

class StudyController {
  StudyController(AppRepository repository, {math.Random? random})
    : _repository = repository,
      _random = random ?? math.Random();

  StudyController.forTesting({math.Random? random})
    : _repository = null,
      _random = random ?? math.Random();

  final AppRepository? _repository;
  final math.Random _random;

  AppRepository get _requiredRepository {
    final repository = _repository;
    if (repository == null) {
      throw StateError(
        'StudyController requires a repository for this action.',
      );
    }
    return repository;
  }

  Future<StudySessionState> load({
    String? collectionId,
    String? deckId,
    TestMode? forcedMode,
    required int sessionCardLimit,
  }) {
    return _requiredRepository.startStudySession(
      collectionId: collectionId,
      deckId: deckId,
      forcedMode: forcedMode,
      sessionCardLimit: sessionCardLimit,
    );
  }

  bool evaluateMultipleChoice(
    StudyCard card,
    int selectedIndex,
    List<String> options,
  ) {
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
    final matches = RegExp(
      r'\{\{([^}]+)\}\}',
    ).allMatches(card.clozeText ?? '').map((match) => match.group(1)!).toList();
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
    return _requiredRepository.submitReview(
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
    final updatedSeenCardIds = {...state.seenCardIds, state.currentCard.id};
    final updatedPendingReviewResults = Map<String, ReviewResult>.from(
      state.pendingReviewResults,
    );

    if (_shouldRepeatInSession(result)) {
      updatedPendingReviewResults[state.currentCard.id] = result;
    } else {
      updatedPendingReviewResults.remove(state.currentCard.id);
    }

    final reviewedCards = state.cards.sublist(0, state.currentIndex + 1);
    final upcomingCards = state.cards.sublist(state.currentIndex + 1);
    final pendingCards = <StudyCard>[
      ...upcomingCards,
      if (_shouldRepeatInSession(result)) state.currentCard,
    ];

    final nextCards =
        state.hasSeenAllCards ||
            updatedSeenCardIds.length >= state.sessionCardIds.length
        ? [
            ...reviewedCards,
            ..._reorderPhaseTwoCards(pendingCards, updatedPendingReviewResults),
          ]
        : [...reviewedCards, ...pendingCards];

    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= nextCards.length) {
      return state.copyWith(
        cards: nextCards,
        seenCardIds: updatedSeenCardIds,
        pendingReviewResults: updatedPendingReviewResults,
        reviewCounts: updatedCounts,
        isCompleted: true,
      );
    }

    return state.copyWith(
      cards: nextCards,
      seenCardIds: updatedSeenCardIds,
      pendingReviewResults: updatedPendingReviewResults,
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

  List<StudyCard> _reorderPhaseTwoCards(
    List<StudyCard> cards,
    Map<String, ReviewResult> pendingReviewResults,
  ) {
    final failedCards = cards
        .where((card) => pendingReviewResults[card.id] == ReviewResult.again)
        .toList();
    final successfulCards = cards
        .where((card) => pendingReviewResults[card.id] != ReviewResult.again)
        .toList();

    failedCards.shuffle(_random);
    successfulCards.shuffle(_random);

    return [...failedCards, ...successfulCards];
  }

  bool _shouldRepeatInSession(ReviewResult result) {
    return result == ReviewResult.again || result == ReviewResult.hard;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
