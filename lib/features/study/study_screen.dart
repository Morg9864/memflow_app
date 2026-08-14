import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scaffold_messenger.dart';
import '../../app/session_card_limit_controller.dart';
import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import 'mode_selection_sheet.dart';
import 'study_controller.dart';

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({
    super.key,
    this.collectionId,
    this.deckId,
    this.forcedMode,
    this.controller,
  });

  final String? collectionId;
  final String? deckId;
  final TestMode? forcedMode;
  final StudyController? controller;

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  static const double _desktopBreakpoint = 1100;
  static const double _desktopMaxWidth = 1240;
  static const double _desktopReviewPanelWidth = 340;

  StudySessionState? _state;
  Object? _error;
  late final StudyController _controller;
  final TextEditingController _freeTextController = TextEditingController();
  List<String?> _clozeSelections = const [];
  List<String> _clozeWordBank = const [];
  int? _activeClozeGapIndex;
  final List<_PendingReviewSubmission> _pendingReviewSubmissions = [];
  bool _isApplyingReview = false;
  bool _isProcessingReviewQueue = false;
  bool _isReviewRetryPending = false;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? StudyController(ref.read(appRepositoryProvider));
    if (widget.forcedMode != null) {
      Future.microtask(() => _load(forcedMode: widget.forcedMode));
      return;
    }
    Future.microtask(_askModeAndLoad);
  }

  Future<void> _askModeAndLoad() async {
    if (!mounted) return;
    final choice = await showModeSelectionSheet(context);
    // null = user dismissed without choosing → go back
    if (!mounted) return;
    if (choice == null) {
      _exitStudy();
      return;
    }
    await _load(forcedMode: choice.mode);
  }

  Future<void> _load({TestMode? forcedMode}) async {
    try {
      final session = await _controller.load(
        collectionId: widget.collectionId,
        deckId: widget.deckId,
        forcedMode: forcedMode,
        sessionCardLimit: ref.read(sessionCardLimitProvider),
      );
      final preparedSession = _controller.prepareCurrentCard(session);
      _prepareCardInputState(preparedSession.currentCard);
      if (mounted) {
        setState(() => _state = preparedSession);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  void dispose() {
    _freeTextController.dispose();
    super.dispose();
  }

  void _selectOption(int index, List<String> options) {
    final state = _state;
    if (state == null || state.hasValidatedAnswer) return;
    final isCorrect = _controller.evaluateMultipleChoice(
      state.currentCard,
      index,
      options,
    );
    setState(() {
      _state = state.copyWith(
        selectedOptionIndex: index,
        hasValidatedAnswer: true,
        currentAnswerWasCorrect: isCorrect,
      );
    });
  }

  void _submitTextAnswer({required bool isCloze}) {
    final state = _state;
    if (state == null || state.hasValidatedAnswer) return;
    if (isCloze) {
      final isCorrect = _controller.evaluateCloze(
        state.currentCard,
        _clozeSelections,
      );
      setState(() {
        _state = state.copyWith(
          hasValidatedAnswer: true,
          currentAnswerWasCorrect: isCorrect,
          freeTextAnswer: _clozeSelections.whereType<String>().join(' | '),
        );
        _activeClozeGapIndex = null;
      });
      return;
    }

    final answer = _freeTextController.text.trim();
    final isCorrect = _controller.evaluateFreeText(state.currentCard, answer);
    setState(() {
      _state = state.copyWith(
        hasValidatedAnswer: true,
        currentAnswerWasCorrect: isCorrect,
        freeTextAnswer: answer,
      );
    });
  }

  void _prepareCardInputState(StudyCard card) {
    _freeTextController.clear();
    _activeClozeGapIndex = null;
    if (card.currentTestMode != TestMode.cloze) {
      _clozeSelections = const [];
      _clozeWordBank = const [];
      return;
    }

    _clozeSelections = List<String?>.filled(
      card.clozeAnswers.length,
      null,
      growable: false,
    );
    _clozeWordBank = _controller.buildClozeWordBank(card);
  }

  void _selectClozeGap(int gapIndex) {
    final state = _state;
    if (state == null || state.hasValidatedAnswer) {
      return;
    }

    final nextSelections = List<String?>.from(_clozeSelections);
    final hadWord = nextSelections[gapIndex] != null;
    if (hadWord) {
      nextSelections[gapIndex] = null;
    }

    setState(() {
      _clozeSelections = List<String?>.unmodifiable(nextSelections);
      _activeClozeGapIndex = gapIndex;
    });
  }

  void _fillClozeGap(String word) {
    final state = _state;
    if (state == null || state.hasValidatedAnswer) {
      return;
    }

    final gapIndex =
        _activeClozeGapIndex ??
        _clozeSelections.indexWhere((value) => value == null);
    if (gapIndex < 0) {
      return;
    }

    final nextSelections = List<String?>.from(_clozeSelections);
    nextSelections[gapIndex] = word;
    setState(() {
      _clozeSelections = List<String?>.unmodifiable(nextSelections);
      _activeClozeGapIndex = _nextEmptyClozeGap(nextSelections, gapIndex);
    });
  }

  int? _nextEmptyClozeGap(List<String?> selections, int currentIndex) {
    for (var index = currentIndex + 1; index < selections.length; index++) {
      if (selections[index] == null) {
        return index;
      }
    }
    for (var index = 0; index < currentIndex; index++) {
      if (selections[index] == null) {
        return index;
      }
    }
    return null;
  }

  List<String> _availableClozeWords() {
    final selectedCounts = <String, int>{};
    for (final word in _clozeSelections.whereType<String>()) {
      selectedCounts.update(word, (count) => count + 1, ifAbsent: () => 1);
    }

    final available = <String>[];
    for (final word in _clozeWordBank) {
      final count = selectedCounts[word] ?? 0;
      if (count > 0) {
        selectedCounts[word] = count - 1;
        continue;
      }
      available.add(word);
    }
    return available;
  }

  Future<void> _applyReview(ReviewResult result) async {
    final state = _state;
    if (state == null || _isApplyingReview) return;

    _isApplyingReview = true;
    try {
      final submission = _PendingReviewSubmission(
        cardId: state.currentCard.id,
        result: result,
        wasCorrect:
            state.currentAnswerWasCorrect ?? result != ReviewResult.again,
        playedMode: state.currentCard.currentTestMode,
      );
      final nextState = _controller.advance(state, result);

      _queueReviewSubmission(submission);

      if (nextState.isCompleted) {
        if (!mounted) return;
        context.go(
          '/session-summary',
          extra: _controller.buildSummary(nextState),
        );
        return;
      }

      if (!mounted) return;
      _prepareCardInputState(nextState.currentCard);
      setState(() => _state = nextState);
    } finally {
      _isApplyingReview = false;
    }
  }

  void _queueReviewSubmission(_PendingReviewSubmission submission) {
    _pendingReviewSubmissions.add(submission);
    if (_isReviewRetryPending || _isProcessingReviewQueue) {
      return;
    }
    unawaited(_flushPendingReviewSubmissions());
  }

  Future<void> _flushPendingReviewSubmissions() async {
    if (_isProcessingReviewQueue || _isReviewRetryPending) {
      return;
    }

    _isProcessingReviewQueue = true;
    try {
      while (_pendingReviewSubmissions.isNotEmpty) {
        final submission = _pendingReviewSubmissions.first;
        try {
          await _controller.submitReview(
            cardId: submission.cardId,
            result: submission.result,
            wasCorrect: submission.wasCorrect,
            playedMode: submission.playedMode,
          );
          _pendingReviewSubmissions.removeAt(0);
        } catch (_) {
          _isReviewRetryPending = true;
          _showReviewSaveError();
          break;
        }
      }
    } finally {
      _isProcessingReviewQueue = false;
    }
  }

  void _retryPendingReviewSubmissions() {
    if (_pendingReviewSubmissions.isEmpty) {
      _isReviewRetryPending = false;
      return;
    }

    _isReviewRetryPending = false;
    unawaited(_flushPendingReviewSubmissions());
  }

  void _showReviewSaveError() {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'La carte suivante est déjà prête, mais une sauvegarde a échoué.',
          ),
          action: SnackBarAction(
            label: 'Réessayer',
            onPressed: _retryPendingReviewSubmissions,
          ),
        ),
      );
  }

  void _reveal() {
    final state = _state;
    if (state == null) return;
    setState(() => _state = state.copyWith(revealed: true));
  }

  void _exitStudy() {
    if (!mounted) {
      return;
    }

    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }

    final fallbackCollectionId =
        widget.collectionId ??
        _state?.collectionId ??
        _state?.currentCard.collectionId;
    if (fallbackCollectionId != null) {
      context.go('/collection/$fallbackCollectionId');
      return;
    }

    context.go('/');
  }

  bool _canPopStudy() {
    return Navigator.of(context).canPop();
  }

  void _handlePopInvoked(bool didPop) {
    if (didPop) {
      return;
    }

    _exitStudy();
  }

  String _sessionErrorMessage(Object error) {
    final rawMessage = error is StateError
        ? error.message.toString()
        : error.toString();

    if (rawMessage.contains('Aucune carte disponible')) {
      return 'Il n’y a aucune carte à réviser ici pour le moment.';
    }
    if (rawMessage.contains('Deck introuvable')) {
      return 'Ce deck n’est plus disponible.';
    }
    if (rawMessage.contains('Collection introuvable')) {
      return 'Cette collection n’est plus disponible.';
    }
    return 'Impossible de démarrer cette session pour le moment.';
  }

  bool _isDesktopPlatform() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  _ReviewFeedback _reviewFeedback({
    required TestMode mode,
    required StudyCard card,
    required StudySessionState state,
    required String clozeSolution,
  }) {
    return switch (mode) {
      TestMode.multipleChoice => _ReviewFeedback(
        label: state.currentAnswerWasCorrect == true
            ? 'Bonne réponse'
            : 'Réponse attendue',
        answer: card.correctAnswer,
        explanation: card.explanation,
      ),
      TestMode.cloze => _ReviewFeedback(
        label: state.currentAnswerWasCorrect == true
            ? 'Bien joué'
            : 'Texte complété',
        answer: clozeSolution,
        explanation: card.explanation,
        resultIsCorrect: state.currentAnswerWasCorrect,
      ),
      TestMode.freeText => _ReviewFeedback(
        label: state.currentAnswerWasCorrect == true ? 'Bien joué' : 'Réponse',
        answer: card.correctAnswer,
        explanation: card.explanation,
        resultIsCorrect: state.currentAnswerWasCorrect,
      ),
      TestMode.trueFalse => _ReviewFeedback(
        label: 'Réponse correcte',
        answer: card.correctAnswer,
        explanation: card.explanation,
      ),
      TestMode.reversedFlashcard => _ReviewFeedback(
        label: 'Concept visé',
        answer: card.question,
        explanation: card.explanation,
      ),
      _ => _ReviewFeedback(
        label: 'Réponse',
        answer: card.correctAnswer,
        explanation: card.explanation,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (_error != null) {
      return PopScope(
        canPop: _canPopStudy(),
        onPopInvokedWithResult: (didPop, _) => _handlePopInvoked(didPop),
        child: Scaffold(
          body: SafeArea(
            child: EmptyState(
              title: 'Session indisponible',
              message: _sessionErrorMessage(_error!),
              action: FilledButton(
                onPressed: _exitStudy,
                child: const Text('Retour'),
              ),
            ),
          ),
        ),
      );
    }
    if (state == null) {
      return PopScope(
        canPop: _canPopStudy(),
        onPopInvokedWithResult: (didPop, _) => _handlePopInvoked(didPop),
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final card = state.currentCard;
    final mode = card.currentTestMode;
    final suggested = _controller.suggestedResult(
      state.currentAnswerWasCorrect,
    );
    final options = mode == TestMode.multipleChoice
        ? card.buildOptions()
        : const <String>[];
    final clozeTokens = mode == TestMode.cloze
        ? _controller.buildClozeTokens(card)
        : const <ClozeToken>[];
    final clozeResults = mode == TestMode.cloze
        ? _controller.evaluateClozeGaps(card, _clozeSelections)
        : const <bool>[];
    final clozeSolution = mode == TestMode.cloze
        ? _controller.buildClozeSolution(card)
        : '';
    final availableClozeWords = mode == TestMode.cloze
        ? _availableClozeWords()
        : const <String>[];
    // Proposition stable affichée en mode vrai/faux (fallback sûr sur la bonne
    // réponse si l'état n'en contient pas encore ou est vide).
    final storedProposition = state.trueFalseProposition;
    final trueFalseProposition =
        (storedProposition == null || storedProposition.trim().isEmpty)
        ? card.correctAnswer
        : storedProposition;

    final showsReview = _needsReviewButtons(mode, state);

    return PopScope(
      canPop: _canPopStudy(),
      onPopInvokedWithResult: (didPop, _) => _handlePopInvoked(didPop),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewportConstraints) {
              final isWideDesktop =
                  _isDesktopPlatform() &&
                  viewportConstraints.maxWidth >= _desktopBreakpoint;
              final usesReviewPanel = isWideDesktop && showsReview;
              final maxWidth = isWideDesktop
                  ? _desktopMaxWidth
                  : AppTheme.contentMaxWidth;

              final modeContent = AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: switch (mode) {
                  TestMode.multipleChoice => _McqMode(
                    key: ValueKey('mcq-${card.id}-${state.hasValidatedAnswer}'),
                    card: card,
                    options: options,
                    selectedIndex: state.selectedOptionIndex,
                    hasValidatedAnswer: state.hasValidatedAnswer,
                    desktopGrid: isWideDesktop,
                    showInlineFeedback: !usesReviewPanel,
                    onSelect: _selectOption,
                  ),
                  TestMode.cloze => _ClozeMode(
                    key: ValueKey(
                      'cloze-${card.id}-${state.hasValidatedAnswer}',
                    ),
                    prompt: card.question,
                    tokens: clozeTokens,
                    selectedWords: _clozeSelections,
                    availableWords: availableClozeWords,
                    activeGapIndex: _activeClozeGapIndex,
                    hasValidated: state.hasValidatedAnswer,
                    isCorrect: state.currentAnswerWasCorrect,
                    validationResults: clozeResults,
                    solutionText: clozeSolution,
                    hint: card.hint,
                    explanation: card.explanation,
                    showInlineFeedback: !usesReviewPanel,
                    onGapTap: _selectClozeGap,
                    onWordTap: _fillClozeGap,
                    onSubmit: () => _submitTextAnswer(isCloze: true),
                  ),
                  TestMode.freeText => _TextEntryMode(
                    key: ValueKey(
                      'free-${card.id}-${state.hasValidatedAnswer}',
                    ),
                    title: 'Saisie libre',
                    prompt: card.question,
                    hint: card.hint,
                    controller: _freeTextController,
                    hasValidated: state.hasValidatedAnswer,
                    isCorrect: state.currentAnswerWasCorrect,
                    answerLabel: 'Réponse',
                    answerText: card.correctAnswer,
                    explanation: card.explanation,
                    showInlineFeedback: !usesReviewPanel,
                    actionLabel: 'Vérifier',
                    onSubmit: () => _submitTextAnswer(isCloze: false),
                  ),
                  TestMode.trueFalse => _TrueFalseMode(
                    key: ValueKey('tf-${card.id}-${state.hasValidatedAnswer}'),
                    card: card,
                    proposition: trueFalseProposition,
                    propositionIsCorrect: _controller
                        .isTrueFalsePropositionCorrect(
                          card,
                          trueFalseProposition,
                        ),
                    selectedIndex: state.selectedOptionIndex,
                    hasValidatedAnswer: state.hasValidatedAnswer,
                    showInlineFeedback: !usesReviewPanel,
                    onSelect: (index) {
                      final correct = _controller.evaluateTrueFalse(
                        card,
                        trueFalseProposition,
                        answeredTrue: index == 0,
                      );
                      setState(() {
                        _state = state.copyWith(
                          selectedOptionIndex: index,
                          hasValidatedAnswer: true,
                          currentAnswerWasCorrect: correct,
                        );
                      });
                    },
                  ),
                  _ => _FlashcardMode(
                    key: ValueKey('flash-${card.id}-${state.revealed}'),
                    card: card,
                    revealed: state.revealed,
                    reversed: mode == TestMode.reversedFlashcard,
                    showInlineAnswer: !usesReviewPanel,
                    onReveal: _reveal,
                  ),
                },
              );

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: GestureDetector(
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity != null &&
                          details.primaryVelocity! < -200 &&
                          !state.revealed &&
                          (mode == TestMode.classicFlashcard ||
                              mode == TestMode.reversedFlashcard)) {
                        _reveal();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StudyProgressHeader(
                            title: state.deckTitle,
                            currentIndex: state.currentIndex,
                            total: state.cards.length,
                            level: card.level,
                            progressDots: card.progressDots,
                            onClose: _exitStudy,
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: usesReviewPanel
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        key: const Key('desktop-study-content'),
                                        child: modeContent,
                                      ),
                                      const SizedBox(width: 24),
                                      SizedBox(
                                        width: _desktopReviewPanelWidth,
                                        child: _DesktopReviewPanel(
                                          feedback: _reviewFeedback(
                                            mode: mode,
                                            card: card,
                                            state: state,
                                            clozeSolution: clozeSolution,
                                          ),
                                          suggested: suggested,
                                          onReview: _applyReview,
                                        ),
                                      ),
                                    ],
                                  )
                                : Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: AppTheme.contentMaxWidth,
                                      ),
                                      child: modeContent,
                                    ),
                                  ),
                          ),
                          if (showsReview && !usesReviewPanel) ...[
                            const SizedBox(height: 18),
                            const SectionLabel('Comment tu t’en es sorti ?'),
                            const SizedBox(height: 12),
                            GridView.count(
                              key: const Key('inline-review-controls'),
                              crossAxisCount:
                                  MediaQuery.of(context).size.width > 700
                                  ? 4
                                  : 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.55,
                              children: [
                                for (final result in ReviewResult.values)
                                  ReviewButton(
                                    result: result,
                                    isSuggested: result == suggested,
                                    onPressed: () => _applyReview(result),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  bool _needsReviewButtons(TestMode mode, StudySessionState state) {
    if (mode == TestMode.multipleChoice ||
        mode == TestMode.cloze ||
        mode == TestMode.freeText ||
        mode == TestMode.trueFalse) {
      return state.hasValidatedAnswer;
    }
    return state.revealed;
  }
}

class _PendingReviewSubmission {
  const _PendingReviewSubmission({
    required this.cardId,
    required this.result,
    required this.wasCorrect,
    required this.playedMode,
  });

  final String cardId;
  final ReviewResult result;
  final bool wasCorrect;

  /// Mode réellement présenté : c'est lui qui est journalisé et qui fait
  /// avancer la carte, pas le mode stocké avant la session.
  final TestMode playedMode;
}

class _ReviewFeedback {
  const _ReviewFeedback({
    required this.label,
    required this.answer,
    required this.explanation,
    this.resultIsCorrect,
  });

  final String label;
  final String answer;
  final String? explanation;
  final bool? resultIsCorrect;
}

class _DesktopReviewPanel extends StatelessWidget {
  const _DesktopReviewPanel({
    required this.feedback,
    required this.suggested,
    required this.onReview,
  });

  final _ReviewFeedback feedback;
  final ReviewResult suggested;
  final ValueChanged<ReviewResult> onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resultIsCorrect = feedback.resultIsCorrect;
    final tone = switch (resultIsCorrect) {
      true => const Color(0xFF245433),
      false => const Color(0xFF8E2F24),
      null => theme.colorScheme.onSurface,
    };
    final background = switch (resultIsCorrect) {
      true => const Color(0xFFEAF3E7),
      false => const Color(0xFFFBE7E4),
      null => theme.colorScheme.surface,
    };

    return Card(
      key: const Key('desktop-review-panel'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ColoredBox(
              color: background,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feedback.label.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(color: tone),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      feedback.answer,
                      style: theme.textTheme.titleLarge?.copyWith(color: tone),
                    ),
                    if (feedback.explanation != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        feedback.explanation!,
                        style: theme.textTheme.bodyLarge?.copyWith(color: tone),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Comment tu t’en es sorti ?'),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ReviewResult.values.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 90,
                  ),
                  itemBuilder: (context, index) {
                    final result = ReviewResult.values[index];
                    return ReviewButton(
                      result: result,
                      isSuggested: result == suggested,
                      compact: true,
                      onPressed: () => onReview(result),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashcardMode extends StatelessWidget {
  const _FlashcardMode({
    super.key,
    required this.card,
    required this.revealed,
    required this.reversed,
    required this.showInlineAnswer,
    required this.onReveal,
  });

  final StudyCard card;
  final bool revealed;
  final bool reversed;
  final bool showInlineAnswer;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    if (!revealed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SectionLabel(reversed ? 'Concept' : 'Question'),
            const SizedBox(height: 18),
            Text(
              reversed ? card.correctAnswer : card.question,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (card.hint != null) ...[
              const SizedBox(height: 18),
              Text(
                card.hint!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 28),
            Text(
              'Glisse vers le haut',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onReveal,
              child: const Text('Révéler la réponse'),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Question'),
                const SizedBox(height: 12),
                Text(
                  reversed ? card.correctAnswer : card.question,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (showInlineAnswer) ...[
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 18),
                  SectionLabel(reversed ? 'Concept visé' : 'Réponse'),
                  const SizedBox(height: 12),
                  Text(
                    reversed ? card.question : card.correctAnswer,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (card.explanation != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      card.explanation!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _McqMode extends StatelessWidget {
  const _McqMode({
    super.key,
    required this.card,
    required this.options,
    required this.selectedIndex,
    required this.hasValidatedAnswer,
    required this.desktopGrid,
    required this.showInlineFeedback,
    required this.onSelect,
  });

  final StudyCard card;
  final List<String> options;
  final int? selectedIndex;
  final bool hasValidatedAnswer;
  final bool desktopGrid;
  final bool showInlineFeedback;
  final void Function(int index, List<String> options) onSelect;

  @override
  Widget build(BuildContext context) {
    final correctIndex = options.indexWhere(
      (item) => item == card.correctAnswer,
    );
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Question'),
                const SizedBox(height: 14),
                Text(
                  card.question,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (card.hint != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    card.hint!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (desktopGrid)
          LayoutBuilder(
            builder: (context, constraints) {
              final optionWidth = (constraints.maxWidth - 10) / 2;
              final optionHeight = _McqOptionTile.uniformHeight(
                context,
                options,
                optionWidth,
              );
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var index = 0; index < options.length; index++)
                    SizedBox(
                      width: optionWidth,
                      height: optionHeight,
                      child: _McqOptionTile(
                        text: options[index],
                        isSelected: selectedIndex == index,
                        isCorrect: hasValidatedAnswer && index == correctIndex,
                        isWrong:
                            hasValidatedAnswer &&
                            selectedIndex == index &&
                            selectedIndex != correctIndex,
                        onTap: hasValidatedAnswer
                            ? null
                            : () => onSelect(index, options),
                      ),
                    ),
                ],
              );
            },
          )
        else
          for (var index = 0; index < options.length; index++) ...[
            _McqOptionTile(
              text: options[index],
              isSelected: selectedIndex == index,
              isCorrect: hasValidatedAnswer && index == correctIndex,
              isWrong:
                  hasValidatedAnswer &&
                  selectedIndex == index &&
                  selectedIndex != correctIndex,
              onTap: hasValidatedAnswer ? null : () => onSelect(index, options),
            ),
            const SizedBox(height: 10),
          ],
        if (hasValidatedAnswer && showInlineFeedback) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(
                    selectedIndex == correctIndex
                        ? 'Bonne réponse'
                        : 'Réponse attendue',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    card.correctAnswer,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (card.explanation != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      card.explanation!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _McqOptionTile extends StatelessWidget {
  const _McqOptionTile({
    required this.text,
    required this.isSelected,
    required this.isCorrect,
    required this.isWrong,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final VoidCallback? onTap;

  static const double _padding = 18;
  static const double _borderWidth = 1;

  /// Hauteur commune à toutes les bulles d'une grille : celle de l'option la
  /// plus longue, pour que la grille reste régulière quel que soit le texte.
  static double uniformHeight(
    BuildContext context,
    List<String> options,
    double tileWidth,
  ) {
    final style = Theme.of(context).textTheme.bodyLarge;
    final textScaler = MediaQuery.textScalerOf(context);
    final maxTextWidth = math.max(
      0.0,
      tileWidth - (_padding + _borderWidth) * 2,
    );
    var tallest = 0.0;
    for (final option in options) {
      final painter = TextPainter(
        text: TextSpan(text: option, style: style),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
      )..layout(maxWidth: maxTextWidth);
      tallest = math.max(tallest, painter.height);
      painter.dispose();
    }
    return tallest + (_padding + _borderWidth) * 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isCorrect
        ? const Color(0xFF4D9461)
        : isWrong
        ? const Color(0xFFD94A3A)
        : theme.dividerColor;
    final background = isCorrect
        ? const Color(0xFFEAF3E7)
        : isWrong
        ? const Color(0xFFFBE7E4)
        : isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.1)
        : theme.cardTheme.color;
    final foreground = isCorrect
        ? const Color(0xFF245433)
        : isWrong
        ? const Color(0xFF8E2F24)
        : isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(_padding),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: _borderWidth),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClozeMode extends StatelessWidget {
  const _ClozeMode({
    super.key,
    required this.prompt,
    required this.tokens,
    required this.selectedWords,
    required this.availableWords,
    required this.activeGapIndex,
    required this.hasValidated,
    required this.isCorrect,
    required this.validationResults,
    required this.solutionText,
    required this.hint,
    required this.explanation,
    required this.showInlineFeedback,
    required this.onGapTap,
    required this.onWordTap,
    required this.onSubmit,
  });

  final String prompt;
  final List<ClozeToken> tokens;
  final List<String?> selectedWords;
  final List<String> availableWords;
  final int? activeGapIndex;
  final bool hasValidated;
  final bool? isCorrect;
  final List<bool> validationResults;
  final String solutionText;
  final String? hint;
  final String? explanation;
  final bool showInlineFeedback;
  final void Function(int gapIndex) onGapTap;
  final void Function(String word) onWordTap;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feedbackTone = isCorrect == true
        ? const Color(0xFF245433)
        : const Color(0xFF8E2F24);
    final feedbackBackground = isCorrect == true
        ? const Color(0xFFEAF3E7)
        : const Color(0xFFFBE7E4);
    final promptStyle =
        theme.textTheme.headlineSmall?.copyWith(height: 1.5) ??
        theme.textTheme.titleLarge;

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Question'),
                const SizedBox(height: 12),
                Text(prompt, style: theme.textTheme.titleMedium),
                const SizedBox(height: 22),
                const SectionLabel('Complète le texte'),
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(
                    style: promptStyle,
                    children: [
                      for (final token in tokens)
                        if (!token.isGap)
                          TextSpan(text: token.text)
                        else
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: _ClozeBlankChip(
                                text: selectedWords[token.gapIndex!] ?? '_____',
                                isActive:
                                    !hasValidated &&
                                    activeGapIndex == token.gapIndex,
                                isFilled:
                                    selectedWords[token.gapIndex!] != null,
                                isValidated: hasValidated,
                                isCorrect: hasValidated
                                    ? validationResults[token.gapIndex!]
                                    : null,
                                onTap: hasValidated
                                    ? null
                                    : () => onGapTap(token.gapIndex!),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Appuie sur un trou puis sur un mot de la banque.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    hint!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Banque de mots'),
                const SizedBox(height: 12),
                if (availableWords.isEmpty)
                  Text(
                    hasValidated
                        ? 'Tous les mots sont placés.'
                        : 'Tous les mots de la banque sont actuellement utilisés.',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final word in availableWords)
                        _ClozeWordChip(
                          text: word,
                          enabled: !hasValidated,
                          onTap: hasValidated ? null : () => onWordTap(word),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: hasValidated ? null : onSubmit,
                  child: const Text('Valider ma réponse'),
                ),
              ],
            ),
          ),
        ),
        if (hasValidated && showInlineFeedback) ...[
          const SizedBox(height: 16),
          Card(
            color: feedbackBackground,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (isCorrect == true ? 'Bien joué' : 'Texte complété')
                        .toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: feedbackTone,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    solutionText,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: feedbackTone,
                    ),
                  ),
                  if (explanation != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      explanation!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: feedbackTone,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ClozeBlankChip extends StatelessWidget {
  const _ClozeBlankChip({
    required this.text,
    required this.isActive,
    required this.isFilled,
    required this.isValidated,
    required this.isCorrect,
    required this.onTap,
  });

  final String text;
  final bool isActive;
  final bool isFilled;
  final bool isValidated;
  final bool? isCorrect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isValidated
        ? (isCorrect == true
              ? const Color(0xFF4D9461)
              : const Color(0xFFD94A3A))
        : isActive
        ? theme.colorScheme.primary
        : isFilled
        ? theme.colorScheme.primary.withValues(alpha: 0.55)
        : theme.dividerColor;
    final background = isValidated
        ? (isCorrect == true
              ? const Color(0xFFEAF3E7)
              : const Color(0xFFFBE7E4))
        : isActive
        ? theme.colorScheme.primary.withValues(alpha: 0.14)
        : isFilled
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surface;
    final foreground = isValidated
        ? (isCorrect == true
              ? const Color(0xFF245433)
              : const Color(0xFF8E2F24))
        : isFilled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 76),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}

class _ClozeWordChip extends StatelessWidget {
  const _ClozeWordChip({
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  final String text;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: enabled
                ? theme.colorScheme.primary.withValues(alpha: 0.25)
                : theme.dividerColor,
          ),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: enabled
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _TextEntryMode extends StatelessWidget {
  const _TextEntryMode({
    super.key,
    required this.title,
    required this.prompt,
    required this.hint,
    required this.controller,
    required this.hasValidated,
    required this.isCorrect,
    required this.answerLabel,
    required this.answerText,
    required this.explanation,
    required this.showInlineFeedback,
    required this.actionLabel,
    required this.onSubmit,
  });

  final String title;
  final String prompt;
  final String? hint;
  final TextEditingController controller;
  final bool hasValidated;
  final bool? isCorrect;
  final String answerLabel;
  final String answerText;
  final String? explanation;
  final bool showInlineFeedback;
  final String actionLabel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final feedbackTone = isCorrect == true
        ? const Color(0xFF245433)
        : const Color(0xFF8E2F24);
    final feedbackBackground = isCorrect == true
        ? const Color(0xFFEAF3E7)
        : const Color(0xFFFBE7E4);

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(title),
                const SizedBox(height: 14),
                Text(prompt, style: Theme.of(context).textTheme.headlineMedium),
                if (hint != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    hint!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  enabled: !hasValidated,
                  decoration: const InputDecoration(hintText: 'Ta réponse'),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: hasValidated ? null : onSubmit,
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
        if (hasValidated && showInlineFeedback) ...[
          const SizedBox(height: 16),
          Card(
            color: feedbackBackground,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (isCorrect == true ? 'Bien joué' : answerLabel)
                        .toUpperCase(),
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: feedbackTone),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    answerText,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: feedbackTone),
                  ),
                  if (explanation != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      explanation!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: feedbackTone),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TrueFalseMode extends StatelessWidget {
  const _TrueFalseMode({
    super.key,
    required this.card,
    required this.proposition,
    required this.propositionIsCorrect,
    required this.selectedIndex,
    required this.hasValidatedAnswer,
    required this.showInlineFeedback,
    required this.onSelect,
  });

  final StudyCard card;
  final String proposition;
  final bool propositionIsCorrect;
  final int? selectedIndex;
  final bool hasValidatedAnswer;
  final bool showInlineFeedback;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    // "Vrai" (index 0) est la bonne réponse quand la proposition affichée
    // correspond à la bonne réponse, sinon c'est "Faux" (index 1).
    final correctIndex = propositionIsCorrect ? 0 : 1;
    final theme = Theme.of(context);

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Question'),
                const SizedBox(height: 12),
                Text(card.question, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 18),
                // Petit séparateur visuel entre la question et la réponse
                // proposée (volontairement plus court que la ligne pleine).
                Container(
                  width: 44,
                  height: 3,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                const SectionLabel('Cette réponse est-elle correcte ?'),
                const SizedBox(height: 12),
                Text(proposition, style: theme.textTheme.headlineSmall),
                if (card.hint != null) ...[
                  const SizedBox(height: 22),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    card.hint!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final item in [('Vrai', 0), ('Faux', 1)]) ...[
          _McqOptionTile(
            text: item.$1,
            isSelected: selectedIndex == item.$2,
            isCorrect: hasValidatedAnswer && item.$2 == correctIndex,
            isWrong:
                hasValidatedAnswer &&
                selectedIndex == item.$2 &&
                selectedIndex != correctIndex,
            onTap: hasValidatedAnswer ? null : () => onSelect(item.$2),
          ),
          const SizedBox(height: 10),
        ],
        if (hasValidatedAnswer && showInlineFeedback) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Réponse correcte'),
                  const SizedBox(height: 10),
                  Text(card.correctAnswer, style: theme.textTheme.titleLarge),
                  if (card.explanation != null) ...[
                    const SizedBox(height: 14),
                    Text(card.explanation!, style: theme.textTheme.bodyLarge),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
