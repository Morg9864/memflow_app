import 'dart:math' as math;

import '../../data/repositories/app_repository.dart';
import '../../domain/models/models.dart';

class ClozeToken {
  const ClozeToken.text(this.text) : gapIndex = null;

  const ClozeToken.gap(this.gapIndex) : text = null;

  final String? text;
  final int? gapIndex;

  bool get isGap => gapIndex != null;
}

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

  /// Tire au sort la proposition affichée en mode vrai/faux parmi la bonne
  /// réponse et les mauvaises réponses de la carte. Retourne `null` lorsque la
  /// carte n'est pas en mode vrai/faux.
  String? buildTrueFalseProposition(StudyCard card) {
    if (card.currentTestMode != TestMode.trueFalse) {
      return null;
    }
    final wrongAnswers = card.wrongAnswers
        .where((answer) => answer.trim().isNotEmpty)
        .toList();
    final pool = <String>[
      if (card.correctAnswer.trim().isNotEmpty) card.correctAnswer,
      ...wrongAnswers,
    ];
    if (pool.isEmpty) {
      return null;
    }
    return pool[_random.nextInt(pool.length)];
  }

  /// Mémorise dans l'état une proposition stable pour la carte courante.
  /// À appeler au chargement de la session et à chaque changement de carte.
  StudySessionState prepareCurrentCard(StudySessionState state) {
    final proposition = buildTrueFalseProposition(state.currentCard);
    return state.copyWith(
      trueFalseProposition: proposition,
      clearTrueFalseProposition: proposition == null,
    );
  }

  /// Indique si la proposition affichée correspond à la bonne réponse.
  bool isTrueFalsePropositionCorrect(StudyCard card, String proposition) {
    return _normalize(proposition) == _normalize(card.correctAnswer);
  }

  /// Corrige une réponse vrai/faux à partir de la proposition affichée.
  /// "Vrai" ([answeredTrue] = true) est correct si la proposition est la bonne
  /// réponse ; "Faux" est correct si c'est une mauvaise réponse.
  bool evaluateTrueFalse(
    StudyCard card,
    String proposition, {
    required bool answeredTrue,
  }) {
    return answeredTrue == isTrueFalsePropositionCorrect(card, proposition);
  }

  bool evaluateFreeText(StudyCard card, String answer) {
    final normalizedAnswer = _normalize(answer);
    final accepted = card.acceptedAnswers.isEmpty
        ? [_normalize(card.correctAnswer)]
        : card.acceptedAnswers.map(_normalize);
    return accepted.contains(normalizedAnswer);
  }

  List<ClozeToken> buildClozeTokens(StudyCard card) {
    final source = card.clozeText ?? card.question;
    final matches = RegExp(r'\{\{([^}]+)\}\}').allMatches(source).toList();
    if (matches.isEmpty) {
      return [ClozeToken.text(source)];
    }

    final tokens = <ClozeToken>[];
    var cursor = 0;
    for (var gapIndex = 0; gapIndex < matches.length; gapIndex++) {
      final match = matches[gapIndex];
      if (match.start > cursor) {
        tokens.add(ClozeToken.text(source.substring(cursor, match.start)));
      }
      tokens.add(ClozeToken.gap(gapIndex));
      cursor = match.end;
    }
    if (cursor < source.length) {
      tokens.add(ClozeToken.text(source.substring(cursor)));
    }
    return tokens;
  }

  List<String> buildClozeWordBank(StudyCard card) {
    final wordBank = [...card.clozeWordBank];
    wordBank.shuffle(_random);
    return wordBank;
  }

  List<bool> evaluateClozeGaps(StudyCard card, List<String?> answers) {
    return List.generate(card.clozeAnswers.length, (index) {
      final providedAnswer = index < answers.length ? answers[index] : null;
      return _normalize(providedAnswer ?? '') ==
          _normalize(card.clozeAnswers[index]);
    });
  }

  bool evaluateCloze(StudyCard card, List<String?> answers) {
    final results = evaluateClozeGaps(card, answers);
    return results.isNotEmpty && results.every((isCorrect) => isCorrect);
  }

  String buildClozeSolution(StudyCard card) {
    final source = card.clozeText ?? card.question;
    var gapIndex = 0;
    return source.replaceAllMapped(RegExp(r'\{\{([^}]+)\}\}'), (match) {
      final fallback = match.group(1)?.trim() ?? '';
      if (gapIndex >= card.clozeAnswers.length) {
        gapIndex += 1;
        return fallback;
      }
      return card.clozeAnswers[gapIndex++];
    });
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

    final nextProposition = buildTrueFalseProposition(nextCards[nextIndex]);

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
      trueFalseProposition: nextProposition,
      clearTrueFalseProposition: nextProposition == null,
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
    return result == ReviewResult.again;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
