import 'dart:math' as math;

import '../../domain/models/models.dart';
import '../../domain/services/answer_rules.dart';

class ClozeToken {
  const ClozeToken.text(this.text) : gapIndex = null;
  const ClozeToken.gap(this.gapIndex) : text = null;
  final String? text;
  final int? gapIndex;
  bool get isGap => gapIndex != null;
}

/// Study decisions with no persistence or UI dependencies.
class StudyRules {
  StudyRules({math.Random? random}) : _random = random ?? math.Random();
  final math.Random _random;

  bool evaluateMultipleChoice(
    StudyCard card,
    int selectedIndex,
    List<String> options,
  ) {
    if (selectedIndex < 0 || selectedIndex >= options.length) return false;
    return normalizeAnswer(options[selectedIndex]) ==
        normalizeAnswer(card.correctAnswer);
  }

  String? buildTrueFalseProposition(StudyCard card) {
    if (card.currentTestMode != TestMode.trueFalse) return null;
    final pool = <String>[
      if (card.correctAnswer.trim().isNotEmpty) card.correctAnswer,
      ...card.wrongAnswers.where((answer) => answer.trim().isNotEmpty),
    ];
    return pool.isEmpty ? null : pool[_random.nextInt(pool.length)];
  }

  StudySessionState prepareCurrentCard(StudySessionState state) {
    final proposition = buildTrueFalseProposition(state.currentCard);
    return state.copyWith(
      trueFalseProposition: proposition,
      clearTrueFalseProposition: proposition == null,
    );
  }

  bool isTrueFalsePropositionCorrect(StudyCard card, String proposition) =>
      normalizeAnswer(proposition) == normalizeAnswer(card.correctAnswer);
  bool evaluateTrueFalse(
    StudyCard card,
    String proposition, {
    required bool answeredTrue,
  }) => answeredTrue == isTrueFalsePropositionCorrect(card, proposition);

  bool evaluateFreeText(StudyCard card, String answer) {
    final normalized = normalizeAnswer(answer);
    final accepted = card.acceptedAnswers.isEmpty
        ? [normalizeAnswer(card.correctAnswer)]
        : card.acceptedAnswers.map(normalizeAnswer);
    return accepted.contains(normalized);
  }

  List<ClozeToken> buildClozeTokens(StudyCard card) {
    final source = card.clozeText ?? card.question;
    final matches = clozePlaceholderPattern.allMatches(source).toList();
    if (matches.isEmpty) return [ClozeToken.text(source)];
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

  List<String> buildClozeWordBank(StudyCard card) =>
      [...card.clozeWordBank]..shuffle(_random);
  List<bool> evaluateClozeGaps(StudyCard card, List<String?> answers) =>
      List.generate(
        card.clozeAnswers.length,
        (index) =>
            normalizeAnswer(
              index < answers.length ? answers[index] ?? '' : '',
            ) ==
            normalizeAnswer(card.clozeAnswers[index]),
      );
  bool evaluateCloze(StudyCard card, List<String?> answers) {
    final results = evaluateClozeGaps(card, answers);
    return results.isNotEmpty && results.every((result) => result);
  }

  String buildClozeSolution(StudyCard card) {
    final source = card.clozeText ?? card.question;
    var gapIndex = 0;
    return source.replaceAllMapped(clozePlaceholderPattern, (match) {
      if (gapIndex >= card.clozeAnswers.length) {
        return match.group(1)?.trim() ?? '';
      }
      return card.clozeAnswers[gapIndex++];
    });
  }

  SessionSummary buildSummary(StudySessionState state) => SessionSummary(
    collectionId: state.collectionId,
    deckId: state.deckId,
    deckTitle: state.deckTitle,
    totalCards: state.cards.length,
    reviewCounts: state.reviewCounts,
  );
  ReviewResult suggestedResult(bool? wasCorrect) =>
      wasCorrect == null || wasCorrect ? ReviewResult.good : ReviewResult.again;

  StudySessionState advance(StudySessionState state, ReviewResult result) {
    final updatedCounts = Map<ReviewResult, int>.from(state.reviewCounts)
      ..update(result, (value) => value + 1, ifAbsent: () => 1);
    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.cards.length) {
      return state.copyWith(reviewCounts: updatedCounts, isCompleted: true);
    }
    final proposition = buildTrueFalseProposition(state.cards[nextIndex]);
    return state.copyWith(
      currentIndex: nextIndex,
      revealed: false,
      clearSelectedOption: true,
      hasValidatedAnswer: false,
      freeTextAnswer: '',
      reviewCounts: updatedCounts,
      clearCorrectness: true,
      isCompleted: false,
      trueFalseProposition: proposition,
      clearTrueFalseProposition: proposition == null,
    );
  }
}
