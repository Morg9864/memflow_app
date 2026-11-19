import 'dart:math' as math;

import '../../data/repositories/app_repository.dart';
import '../../domain/models/models.dart';
import '../../domain/services/card_mode_service.dart';
import 'study_rules.dart';

export 'study_rules.dart' show ClozeToken, StudyRules;

/// Coordinates persistence with the study rules.
class StudyController {
  StudyController(AppRepository repository, {math.Random? random})
    : _repository = repository,
      _loadSession = repository.startStudySession,
      _submitReview = repository.submitReview,
      _submitReviewWithId = repository.submitReview,
      _saveSession = repository.saveStudySession,
      _savedSession = repository.savedStudySession,
      _modeAvailability = repository.studyModeAvailability,
      _loadErrorSession = repository.startErrorReviewSession,
      _loadDeckErrorSession = repository.startDeckErrorReviewSession,
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
    Future<void> Function(StudySessionState state)? saveSession,
    Future<SavedStudySession?> Function()? savedSession,
    Future<void> Function({
      String? reviewId,
      required String cardId,
      required ReviewResult reviewResult,
      required bool wasCorrect,
      required TestMode playedMode,
    })?
    submitReviewWithId,
    Future<StudyModeAvailability> Function({
      String? collectionId,
      String? deckId,
    })?
    modeAvailability,
    Future<StudySessionState> Function({
      String? collectionId,
      String? deckId,
      required Set<String> cardIds,
      required int sessionCardLimit,
    })?
    loadErrorSession,
    Future<StudySessionState> Function({
      required String deckId,
      required int sessionCardLimit,
    })?
    loadDeckErrorSession,
    math.Random? random,
  }) : _repository = null,
       _loadSession = loadSession,
       _submitReview = submitReview,
       _submitReviewWithId =
           submitReviewWithId ??
           (({
             String? reviewId,
             required String cardId,
             required ReviewResult reviewResult,
             required bool wasCorrect,
             required TestMode playedMode,
           }) => submitReview(
             cardId: cardId,
             reviewResult: reviewResult,
             wasCorrect: wasCorrect,
             playedMode: playedMode,
           )),
       _saveSession = saveSession ?? ((_) async {}),
       _savedSession = savedSession ?? (() async => null),
       _modeAvailability =
           modeAvailability ??
           (({String? collectionId, String? deckId}) async =>
               const StudyModeAvailability(total: 0, compatible: {})),
       _loadErrorSession =
           loadErrorSession ??
           (({
             String? collectionId,
             String? deckId,
             required Set<String> cardIds,
             required int sessionCardLimit,
           }) => loadSession(
             collectionId: collectionId,
             deckId: deckId,
             forcedMode: null,
             sessionCardLimit: sessionCardLimit,
           )),
       _loadDeckErrorSession =
           loadDeckErrorSession ??
           (({required deckId, required sessionCardLimit}) async {
             throw StateError('Révision des erreurs par deck indisponible.');
           }),
       rules = StudyRules(random: random);

  final AppRepository? _repository;
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
  final Future<void> Function({
    String? reviewId,
    required String cardId,
    required ReviewResult reviewResult,
    required bool wasCorrect,
    required TestMode playedMode,
  })
  _submitReviewWithId;
  final Future<void> Function(StudySessionState state) _saveSession;
  final Future<SavedStudySession?> Function() _savedSession;
  final Future<StudyModeAvailability> Function({
    String? collectionId,
    String? deckId,
  })
  _modeAvailability;
  final Future<StudySessionState> Function({
    String? collectionId,
    String? deckId,
    required Set<String> cardIds,
    required int sessionCardLimit,
  })
  _loadErrorSession;
  final Future<StudySessionState> Function({
    required String deckId,
    required int sessionCardLimit,
  })
  _loadDeckErrorSession;
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

  Future<void> submitReviewIdempotent({
    required String reviewId,
    required String cardId,
    required ReviewResult result,
    required bool wasCorrect,
    required TestMode playedMode,
  }) => _submitReviewWithId(
    reviewId: reviewId,
    cardId: cardId,
    reviewResult: result,
    wasCorrect: wasCorrect,
    playedMode: playedMode,
  );

  Future<void> saveSession(StudySessionState state) => _saveSession(state);

  Future<SavedStudySession?> savedSession() => _savedSession();

  Future<StudyModeAvailability> modeAvailability({
    String? collectionId,
    String? deckId,
  }) => _modeAvailability(collectionId: collectionId, deckId: deckId);

  Future<StudyModeAvailability> planningModeAvailability({
    String? collectionId,
    String? deckId,
    String? planId,
  }) => _repository!.planningModeAvailability(
    collectionId: collectionId,
    deckId: deckId,
    planId: planId,
  );

  Future<StudySessionState> loadPlanned({
    String? collectionId,
    String? deckId,
    String? planId,
    TestMode? forcedMode,
    required int sessionCardLimit,
  }) => _repository!.startPlannedStudySession(
    collectionId: collectionId,
    deckId: deckId,
    planId: planId,
    forcedMode: forcedMode,
    sessionCardLimit: sessionCardLimit,
  );

  Future<StudySessionState> loadErrorsOnly({
    String? collectionId,
    String? deckId,
    required Set<String> cardIds,
    required int sessionCardLimit,
  }) => _loadErrorSession(
    collectionId: collectionId,
    deckId: deckId,
    cardIds: cardIds,
    sessionCardLimit: sessionCardLimit,
  );

  Future<StudySessionState> loadDeckErrorsOnly({
    required String deckId,
    required int sessionCardLimit,
  }) =>
      _loadDeckErrorSession(deckId: deckId, sessionCardLimit: sessionCardLimit);

  List<String> buildMultipleChoiceOptions(StudyCard card) =>
      rules.buildMultipleChoiceOptions(card);

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
  StudySessionState advance(
    StudySessionState state,
    ReviewResult result, {
    bool? answerWasCorrect,
    int? clozeCorrectGaps,
    int? clozeTotalGaps,
  }) => rules.advance(
    state,
    result,
    answerWasCorrect: answerWasCorrect,
    clozeCorrectGaps: clozeCorrectGaps,
    clozeTotalGaps: clozeTotalGaps,
  );
}
