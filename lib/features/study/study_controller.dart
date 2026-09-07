import 'dart:math' as math;

import '../../data/repositories/app_repository.dart';
import '../../domain/models/models.dart';
import 'study_rules.dart';

export 'study_rules.dart' show ClozeToken, StudyRules;

/// Coordinates persistence with the study rules.
class StudyController {
  StudyController(AppRepository repository, {math.Random? random})
    : _loadSession = repository.startStudySession,
      _submitReview = repository.submitReview,
      rules = StudyRules(random: random);

  /// Dependency-injected persistence boundary, useful for UI tests and other
  /// adapters without creating a database-backed repository.
  StudyController.fromPersistence({
    required Future<StudySessionState> Function({
      String? collectionId,
      String? deckId,
      TestMode? forcedMode,
      required int sessionCardLimit,
    })
    loadSession,
    required Future<void> Function({
      required String cardId,
      required ReviewResult reviewResult,
      required bool wasCorrect,
      required TestMode playedMode,
    })
    submitReview,
    math.Random? random,
  }) : _loadSession = loadSession,
       _submitReview = submitReview,
       rules = StudyRules(random: random);

  final Future<StudySessionState> Function({
    String? collectionId,
    String? deckId,
    TestMode? forcedMode,
    required int sessionCardLimit,
  })
  _loadSession;
  final Future<void> Function({
    required String cardId,
    required ReviewResult reviewResult,
    required bool wasCorrect,
    required TestMode playedMode,
  })
  _submitReview;
  final StudyRules rules;

  Future<StudySessionState> load({
    String? collectionId,
    String? deckId,
    TestMode? forcedMode,
    required int sessionCardLimit,
  }) => _loadSession(
    collectionId: collectionId,
    deckId: deckId,
    forcedMode: forcedMode,
    sessionCardLimit: sessionCardLimit,
  );

  Future<void> submitReview({
    required String cardId,
    required ReviewResult result,
    required bool wasCorrect,
    required TestMode playedMode,
  }) => _submitReview(
    cardId: cardId,
    reviewResult: result,
    wasCorrect: wasCorrect,
    playedMode: playedMode,
  );

  bool evaluateMultipleChoice(
    StudyCard card,
    int selectedIndex,
    List<String> options,
  ) => rules.evaluateMultipleChoice(card, selectedIndex, options);
  String? buildTrueFalseProposition(StudyCard card) =>
      rules.buildTrueFalseProposition(card);
  StudySessionState prepareCurrentCard(StudySessionState state) =>
      rules.prepareCurrentCard(state);
  bool isTrueFalsePropositionCorrect(StudyCard card, String proposition) =>
      rules.isTrueFalsePropositionCorrect(card, proposition);
  bool evaluateTrueFalse(
    StudyCard card,
    String proposition, {
    required bool answeredTrue,
  }) => rules.evaluateTrueFalse(card, proposition, answeredTrue: answeredTrue);
  bool evaluateFreeText(StudyCard card, String answer) =>
      rules.evaluateFreeText(card, answer);
  List<ClozeToken> buildClozeTokens(StudyCard card) =>
      rules.buildClozeTokens(card);
  List<String> buildClozeWordBank(StudyCard card) =>
      rules.buildClozeWordBank(card);
  List<bool> evaluateClozeGaps(StudyCard card, List<String?> answers) =>
      rules.evaluateClozeGaps(card, answers);
  bool evaluateCloze(StudyCard card, List<String?> answers) =>
      rules.evaluateCloze(card, answers);
  String buildClozeSolution(StudyCard card) => rules.buildClozeSolution(card);
  SessionSummary buildSummary(StudySessionState state) =>
      rules.buildSummary(state);
  ReviewResult suggestedResult(bool? wasCorrect) =>
      rules.suggestedResult(wasCorrect);
  StudySessionState advance(StudySessionState state, ReviewResult result) =>
      rules.advance(state, result);
}
