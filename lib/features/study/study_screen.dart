import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

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
    this.errorCardIds,
    this.controller,
  });

  final String? collectionId;
  final String? deckId;
  final TestMode? forcedMode;
  final Set<String>? errorCardIds;
  final StudyController? controller;

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen>
    with WidgetsBindingObserver {
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
  bool _isApplyingReview = false;
  DateTime? _activeSegmentStartedAt;
  final Map<String, String> _reviewIdsByCard = {};
  final Uuid _uuid = const Uuid();

  void _handleKeyboardPrimaryAction() {
    final state = _state;
    if (state == null) return;
    if (_needsReviewButtons(state.currentCard.currentTestMode, state)) {
      _applyReview(_controller.suggestedResult(state.currentAnswerWasCorrect));
      return;
    }
    final mode = state.currentCard.currentTestMode;
    if ((mode == TestMode.classicFlashcard ||
            mode == TestMode.reversedFlashcard) &&
        !state.revealed) {
      _reveal();
    } else if (mode == TestMode.cloze || mode == TestMode.freeText) {
      _submitTextAnswer(isCloze: mode == TestMode.cloze);
    }
  }

  void _handleKeyboardReview(ReviewResult result) {
    final state = _state;
    if (state != null &&
        _needsReviewButtons(state.currentCard.currentTestMode, state)) {
      _applyReview(result);
    }
  }

  KeyEventResult _handleKeyboardEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || _state == null) {
      return KeyEventResult.ignored;
    }
    final state = _state!;
    if (state.currentCard.currentTestMode == TestMode.multipleChoice &&
        !state.hasValidatedAnswer) {
      final index = switch (event.logicalKey) {
        LogicalKeyboardKey.digit1 => 0,
        LogicalKeyboardKey.digit2 => 1,
        LogicalKeyboardKey.digit3 => 2,
        LogicalKeyboardKey.digit4 => 3,
        _ => null,
      };
      final options = state.currentCard.buildOptions();
      if (index != null && index < options.length) {
        _selectOption(index, options);
        return KeyEventResult.handled;
      }
    }
    final reviewResult = switch (event.logicalKey) {
      LogicalKeyboardKey.digit1 => ReviewResult.again,
      LogicalKeyboardKey.digit2 => ReviewResult.hard,
      LogicalKeyboardKey.digit3 => ReviewResult.good,
      LogicalKeyboardKey.digit4 => ReviewResult.easy,
      _ => null,
    };
    if (reviewResult == null ||
        !_needsReviewButtons(_state!.currentCard.currentTestMode, _state!)) {
      return KeyEventResult.ignored;
    }
    _handleKeyboardReview(reviewResult);
    return KeyEventResult.handled;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    final availability = await _controller.modeAvailability(
      collectionId: widget.collectionId,
      deckId: widget.deckId,
    );
    if (!mounted) return;
    final choice = await showModeSelectionSheet(
      context,
      availability: availability,
    );
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
      final session = widget.errorCardIds == null
          ? await _controller.load(
              collectionId: widget.collectionId,
              deckId: widget.deckId,
              forcedMode: forcedMode,
              sessionCardLimit: ref.read(sessionCardLimitProvider),
            )
          : await _controller.loadErrorsOnly(
              collectionId: widget.collectionId,
              deckId: widget.deckId,
              cardIds: widget.errorCardIds!,
              sessionCardLimit: ref.read(sessionCardLimitProvider),
            );
      final preparedSession = _controller.prepareCurrentCard(session);
      _prepareCardInputState(preparedSession.currentCard);
      if (mounted) {
        _activeSegmentStartedAt = DateTime.now();
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
    WidgetsBinding.instance.removeObserver(this);
    _freeTextController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _activeSegmentStartedAt = DateTime.now();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _captureActiveTime();
    }
  }

  void _captureActiveTime() {
    final current = _state;
    final started = _activeSegmentStartedAt;
    if (current == null || started == null) return;
    final elapsed = DateTime.now().difference(started);
    if (elapsed <= Duration.zero) return;
    final updated = current.copyWith(
      activeDuration: current.activeDuration + elapsed,
    );
    _activeSegmentStartedAt = null;
    if (mounted) setState(() => _state = updated);
    unawaited(_controller.saveSession(updated));
  }

  void _selectOption(int index, List<String> options) {
    final state = _state;
    if (state == null || state.hasValidatedAnswer) return;
    unawaited(HapticFeedback.lightImpact());
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
    unawaited(HapticFeedback.lightImpact());
    if (isCloze) {
      final isCorrect = _controller.evaluateCloze(
        state.currentCard,
        _clozeSelections,
      );
      final gaps = _controller.rules.evaluateClozeGaps(
        state.currentCard,
        _clozeSelections,
      );
      setState(() {
        _state = state.copyWith(
          hasValidatedAnswer: true,
          currentAnswerWasCorrect: isCorrect,
          freeTextAnswer: _clozeSelections.whereType<String>().join(' | '),
          clozeCorrectGaps: gaps.where((value) => value).length,
          clozeTotalGaps: gaps.length,
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
      final activeState = _stateWithCapturedActiveTime(state);
      _activeSegmentStartedAt = DateTime.now();
      final wasCorrect =
          activeState.currentAnswerWasCorrect ?? result != ReviewResult.again;
      // SQLite is the acknowledgement boundary: the UI never advances until
      // the review and scheduling update are durable locally.
      await _controller.submitReviewIdempotent(
        reviewId: _reviewIdsByCard.putIfAbsent(
          activeState.currentCard.id,
          _uuid.v4,
        ),
        cardId: activeState.currentCard.id,
        result: result,
        wasCorrect: wasCorrect,
        playedMode: activeState.currentCard.currentTestMode,
      );
      final nextState = _controller.advance(
        activeState,
        result,
        answerWasCorrect: activeState.currentAnswerWasCorrect,
        clozeCorrectGaps: activeState.clozeTotalGaps > 0
            ? activeState.clozeCorrectGaps
            : null,
        clozeTotalGaps: activeState.clozeTotalGaps > 0
            ? activeState.clozeTotalGaps
            : null,
      );
      await _controller.saveSession(nextState);

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
    } catch (_) {
      // Keep the card visible so the user can retry. Most importantly, a
      // failed local write cannot silently turn into a completed review.
      final messenger = appScaffoldMessengerKey.currentState;
      messenger
        ?..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('La sauvegarde locale a échoué. Réessaie.'),
          ),
        );
    } finally {
      _isApplyingReview = false;
    }
  }

  StudySessionState _stateWithCapturedActiveTime(StudySessionState state) {
    final started = _activeSegmentStartedAt;
    if (started == null) return state;
    final elapsed = DateTime.now().difference(started);
    return elapsed <= Duration.zero
        ? state
        : state.copyWith(activeDuration: state.activeDuration + elapsed);
  }

  void _reveal() {
    final state = _state;
    if (state == null) return;
    unawaited(HapticFeedback.lightImpact());
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
        resultIsCorrect: state.currentAnswerWasCorrect,
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
        resultIsCorrect: state.currentAnswerWasCorrect,
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
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(
                  'Préparation de ta session…',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
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
    final studyShortcuts = <ShortcutActivator, Intent>{};
    if (showsReview) {
      studyShortcuts.addAll({
        const SingleActivator(LogicalKeyboardKey.space):
            const _StudyPrimaryIntent(),
        const SingleActivator(LogicalKeyboardKey.enter):
            const _StudyPrimaryIntent(),
        const SingleActivator(LogicalKeyboardKey.digit1):
            const _StudyReviewIntent(ReviewResult.again),
        const SingleActivator(LogicalKeyboardKey.digit2):
            const _StudyReviewIntent(ReviewResult.hard),
        const SingleActivator(LogicalKeyboardKey.digit3):
            const _StudyReviewIntent(ReviewResult.good),
        const SingleActivator(LogicalKeyboardKey.digit4):
            const _StudyReviewIntent(ReviewResult.easy),
      });
    } else if (mode == TestMode.classicFlashcard ||
        mode == TestMode.reversedFlashcard ||
        mode == TestMode.cloze ||
        mode == TestMode.freeText) {
      studyShortcuts[const SingleActivator(LogicalKeyboardKey.enter)] =
          const _StudyPrimaryIntent();
      if (mode == TestMode.classicFlashcard ||
          mode == TestMode.reversedFlashcard) {
        studyShortcuts[const SingleActivator(LogicalKeyboardKey.space)] =
            const _StudyPrimaryIntent();
      }
    }

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyboardEvent,
      child: Shortcuts(
        shortcuts: studyShortcuts,
        child: Actions(
          actions: <Type, Action<Intent>>{
            _StudyPrimaryIntent: CallbackAction<_StudyPrimaryIntent>(
              onInvoke: (_) {
                _handleKeyboardPrimaryAction();
                return null;
              },
            ),
            _StudyReviewIntent: CallbackAction<_StudyReviewIntent>(
              onInvoke: (intent) {
                _handleKeyboardReview(intent.result);
                return null;
              },
            ),
          },
          child: PopScope(
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

                    final switcherKey = ValueKey('${mode.name}-${card.id}');
                    final modeContent = AnimatedSwitcher(
                      duration: AppMotion.of(context, AppMotion.standard),
                      switchInCurve: AppMotion.standardCurve,
                      switchOutCurve: AppMotion.standardCurve,
                      transitionBuilder: MediaQuery.disableAnimationsOf(context)
                          ? (child, _) => child
                          : _cardTransition,
                      layoutBuilder: _cardLayout,
                      child: switch (mode) {
                        TestMode.multipleChoice => _McqMode(
                          key: switcherKey,
                          card: card,
                          options: options,
                          selectedIndex: state.selectedOptionIndex,
                          hasValidatedAnswer: state.hasValidatedAnswer,
                          desktopGrid: isWideDesktop,
                          showInlineFeedback: !usesReviewPanel,
                          onSelect: _selectOption,
                        ),
                        TestMode.cloze => _ClozeMode(
                          key: switcherKey,
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
                        ),
                        TestMode.freeText => _TextEntryMode(
                          key: switcherKey,
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
                          onSubmit: () => _submitTextAnswer(isCloze: false),
                        ),
                        TestMode.trueFalse => _TrueFalseMode(
                          key: switcherKey,
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
                            unawaited(HapticFeedback.lightImpact());
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
                          key: switcherKey,
                          card: card,
                          revealed: state.revealed,
                          reversed: mode == TestMode.reversedFlashcard,
                          showInlineAnswer: !usesReviewPanel,
                        ),
                      },
                    );

                    // Les notes de lecture longues gardent la priorité sur
                    // les boutons : épinglés seulement si l'écran est assez
                    // haut et le texte pas trop grand.
                    final pinsReview =
                        showsReview &&
                        !usesReviewPanel &&
                        MediaQuery.sizeOf(context).height >= 640 &&
                        MediaQuery.textScalerOf(context).scale(10) / 10 <= 1.3;
                    final inlineReview =
                        showsReview && !usesReviewPanel && !pinsReview;
                    final reviewControls = _ReviewControls(
                      suggested: suggested,
                      onReview: _applyReview,
                      showKeyboardHint: _isDesktopPlatform(),
                    );
                    final isFlashcard =
                        mode == TestMode.classicFlashcard ||
                        mode == TestMode.reversedFlashcard;
                    final isFlashFront = isFlashcard && !state.revealed;

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
                            padding: EdgeInsets.fromLTRB(
                              16,
                              viewportConstraints.maxWidth < 600 ? 8 : 16,
                              16,
                              viewportConstraints.maxWidth < 600 ? 12 : 24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StudyProgressHeader(
                                  title: state.deckTitle,
                                  currentIndex: state.currentIndex,
                                  total: state.cards.length,
                                  level: card.level,
                                  progressDots: card.progressDots,
                                  onClose: _exitStudy,
                                ),
                                SizedBox(
                                  height: viewportConstraints.maxWidth < 600
                                      ? 14
                                      : 24,
                                ),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        key: const Key('desktop-study-content'),
                                        child: _StudyScrollArea(
                                          resetKey: card.id,
                                          centered: isFlashFront,
                                          maxContentWidth: usesReviewPanel
                                              ? double.infinity
                                              : AppTheme.contentMaxWidth,
                                          children: [
                                            modeContent,
                                            if (inlineReview) ...[
                                              const SizedBox(height: 18),
                                              reviewControls,
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (usesReviewPanel) ...[
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
                                    ],
                                  ),
                                ),
                                _StudyActionArea(
                                  constrained: !usesReviewPanel,
                                  primary: _primaryAction(mode, state),
                                  review: pinsReview ? reviewControls : null,
                                ),
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
          ),
        ),
      ),
    );
  }

  static Widget _cardTransition(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  static Widget _cardLayout(Widget? current, List<Widget> previous) {
    return Stack(
      alignment: Alignment.topCenter,
      children: <Widget>[...previous, ?current],
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

  /// Action principale épinglée avant la réponse (libellé + callback).
  (String, VoidCallback)? _primaryAction(
    TestMode mode,
    StudySessionState state,
  ) {
    if (mode == TestMode.classicFlashcard ||
        mode == TestMode.reversedFlashcard) {
      return state.revealed ? null : ('Révéler la réponse', _reveal);
    }
    if (state.hasValidatedAnswer) return null;
    return switch (mode) {
      TestMode.cloze => (
        'Valider ma réponse',
        () => _submitTextAnswer(isCloze: true),
      ),
      TestMode.freeText => (
        'Vérifier',
        () => _submitTextAnswer(isCloze: false),
      ),
      _ => null,
    };
  }
}

class _StudyPrimaryIntent extends Intent {
  const _StudyPrimaryIntent();
}

class _StudyReviewIntent extends Intent {
  const _StudyReviewIntent(this.result);

  final ReviewResult result;
}

/// Zone défilante unique : le même arbre pour tous les états de la carte.
class _StudyScrollArea extends StatefulWidget {
  const _StudyScrollArea({
    required this.resetKey,
    required this.centered,
    required this.maxContentWidth,
    required this.children,
  });

  final Object resetKey;
  final bool centered;
  final double maxContentWidth;
  final List<Widget> children;

  @override
  State<_StudyScrollArea> createState() => _StudyScrollAreaState();
}

class _StudyScrollAreaState extends State<_StudyScrollArea> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(_StudyScrollArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetKey != widget.resetKey &&
        _scrollController.hasClients &&
        _scrollController.offset != 0) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Align(
            alignment: widget.centered ? Alignment.center : Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: widget.children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Zone d'action épinglée sous le contenu : action principale avant la
/// réponse, ou contrôles de notation une fois répondu. Vide sinon.
class _StudyActionArea extends StatelessWidget {
  const _StudyActionArea({
    required this.constrained,
    required this.primary,
    required this.review,
  });

  final bool constrained;
  final (String, VoidCallback)? primary;
  final Widget? review;

  @override
  Widget build(BuildContext context) {
    final Widget? content =
        review ??
        (primary == null
            ? null
            : SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: primary!.$2,
                  child: Text(primary!.$1),
                ),
              ));
    if (content == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constrained ? AppTheme.contentMaxWidth : double.infinity,
          ),
          child: content,
        ),
      ),
    );
  }
}

class _ReviewControls extends StatelessWidget {
  const _ReviewControls({
    required this.suggested,
    required this.onReview,
    required this.showKeyboardHint,
  });

  final ReviewResult suggested;
  final ValueChanged<ReviewResult> onReview;
  final bool showKeyboardHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SectionLabel('Comment tu t’en es sorti ?'),
        const SizedBox(height: 12),
        _ReviewGrid(
          key: const Key('inline-review-controls'),
          suggested: suggested,
          onReview: onReview,
          columns: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
        ),
        if (showKeyboardHint) const _KeyboardHint(),
      ],
    );
  }
}

/// Boutons de notation : les hauteurs suivent le contenu (texte agrandi).
class _ReviewGrid extends StatelessWidget {
  const _ReviewGrid({
    super.key,
    required this.suggested,
    required this.onReview,
    required this.columns,
    this.compact = false,
    this.spacing = 12,
  });

  final ReviewResult suggested;
  final ValueChanged<ReviewResult> onReview;
  final int columns;
  final bool compact;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    const results = ReviewResult.values;
    final rows = (results.length / columns).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) SizedBox(height: spacing),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) SizedBox(width: spacing),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final index = row * columns + col;
                        if (index >= results.length) {
                          return const SizedBox.shrink();
                        }
                        final result = results[index];
                        return _ReviewButton(
                          result: result,
                          isSuggested: result == suggested,
                          compact: compact,
                          onPressed: () => onReview(result),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _KeyboardHint extends StatelessWidget {
  const _KeyboardHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'Clavier : 1 Encore · 2 Difficile · 3 Correct · 4 Facile',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
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
    final resultTone = _ResultTone.of(theme, feedback.resultIsCorrect);
    final tone = resultTone.text;
    final background = resultTone.background;

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
                    Row(
                      children: [
                        if (resultTone.icon != null) ...[
                          Icon(resultTone.icon, size: 18, color: tone),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Expanded(
                          child: Text(
                            feedback.label.toUpperCase(),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: tone,
                            ),
                          ),
                        ),
                      ],
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
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Comment tu t’en es sorti ?'),
                  const SizedBox(height: 12),
                  _ReviewGrid(
                    suggested: suggested,
                    onReview: onReview,
                    columns: 2,
                    compact: true,
                    spacing: 10,
                  ),
                  const _KeyboardHint(),
                ],
              ),
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
  });

  final StudyCard card;
  final bool revealed;
  final bool reversed;
  final bool showInlineAnswer;

  @override
  Widget build(BuildContext context) {
    if (!revealed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: SectionLabel(reversed ? 'Concept' : 'Question')),
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
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
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

/// Taille du texte de la question selon sa longueur : les questions courtes
/// gagnent en présence, les longues restent lisibles sans prendre l'écran.
@visibleForTesting
TextStyle questionTextStyle(TextTheme theme, String text) {
  final length = text.trim().length;
  return (length < 90
      ? theme.headlineMedium
      : length < 200
      ? theme.headlineSmall
      : theme.titleLarge)!;
}

/// Couleurs et icône d'un résultat de réponse (vrai, faux, neutre).
class _ResultTone {
  const _ResultTone({
    required this.text,
    required this.background,
    required this.border,
    required this.icon,
  });

  final Color text;
  final Color background;
  final Color border;
  final IconData? icon;

  factory _ResultTone.of(ThemeData theme, bool? correct) => switch (correct) {
    true => const _ResultTone(
      text: AppColors.resultGoodText,
      background: AppColors.resultGoodSoft,
      border: AppColors.resultGood,
      icon: Icons.check_circle_rounded,
    ),
    false => const _ResultTone(
      text: AppColors.resultBadText,
      background: AppColors.resultBadSoft,
      border: AppColors.resultBad,
      icon: Icons.cancel_rounded,
    ),
    null => _ResultTone(
      text: theme.colorScheme.onSurface,
      background: theme.colorScheme.surface,
      border: theme.colorScheme.outlineVariant,
      icon: null,
    ),
  };
}

/// Bloc question commun à QCM, vrai/faux, saisie libre et trous.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.label,
    required this.question,
    this.hint,
    this.body,
  });

  final String label;
  final String question;
  final String? hint;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            Text(question, style: questionTextStyle(theme.textTheme, question)),
            if (hint != null) ...[
              const SizedBox(height: AppSpacing.md),
              _HintLine(hint: hint!),
            ],
            if (body != null) ...[
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
              body!,
            ],
          ],
        ),
      ),
    );
  }
}

class _HintLine extends StatelessWidget {
  const _HintLine({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: 'Indice : $hint',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              hint,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFamily: 'Lora',
                fontStyle: FontStyle.italic,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Retour après validation : label, bonne réponse, explication. Apparition
/// courte (fondu + hauteur, explication un temps après) puis, si la carte est
/// masquée par la zone épinglée, défilement jusqu'à elle.
class _FeedbackCard extends StatefulWidget {
  const _FeedbackCard({
    required this.resultIsCorrect,
    required this.label,
    required this.answer,
    required this.explanation,
  });

  final bool? resultIsCorrect;
  final String label;
  final String answer;
  final String? explanation;

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  @override
  void initState() {
    super.initState();
    // Sans animation la carte a déjà sa taille finale ; sinon on attend la
    // fin de l'apparition (onEnd) pour viser la bonne position.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && MediaQuery.disableAnimationsOf(context)) _bringIntoView();
    });
  }

  void _bringIntoView() {
    if (!mounted) return;
    final viewport = Scrollable.maybeOf(context)?.position.viewportDimension;
    final height = (context.findRenderObject() as RenderBox?)?.size.height;
    // Une carte plus haute que l'écran reste alignée sur son début.
    final tooTall = viewport != null && height != null && height > viewport;
    Scrollable.ensureVisible(
      context,
      duration: AppMotion.of(context, AppMotion.standard),
      curve: AppMotion.standardCurve,
      alignment: 0,
      alignmentPolicy: tooTall
          ? ScrollPositionAlignmentPolicy.explicit
          : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  Widget _card(BuildContext context, double progress) {
    final theme = Theme.of(context);
    final tone = _ResultTone.of(theme, widget.resultIsCorrect);
    final explanation = widget.explanation;
    final explanationOpacity = ((progress - 0.5) * 2).clamp(0.0, 1.0);
    return Card(
      color: tone.background,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.radiusMd,
        side: BorderSide(color: tone.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (tone.icon != null) ...[
                  Icon(tone.icon, size: 18, color: tone.text),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.label.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tone.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.answer,
              style: theme.textTheme.titleLarge?.copyWith(color: tone.text),
            ),
            if (explanation != null) ...[
              const SizedBox(height: 14),
              Opacity(
                opacity: explanationOpacity,
                child: Text(
                  explanation,
                  style: theme.textTheme.bodyLarge?.copyWith(color: tone.text),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pas d'AnimatedSize ici : il lève une assertion avec une durée nulle.
    if (MediaQuery.disableAnimationsOf(context)) return _card(context, 1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.standard,
      curve: AppMotion.standardCurve,
      onEnd: _bringIntoView,
      builder: (context, t, _) => Opacity(
        opacity: t,
        child: ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: SizedBox(width: double.infinity, child: _card(context, t)),
          ),
        ),
      ),
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
    final compact = MediaQuery.sizeOf(context).width < 600;
    final correctIndex = options.indexWhere(
      (item) => item == card.correctAnswer,
    );
    final answeredCorrectly = selectedIndex == correctIndex;
    _McqOptionTile tile(int index, {bool reserveCaption = false}) {
      return _McqOptionTile(
        text: options[index],
        shortcutLabel: String.fromCharCode(65 + index),
        isSelected: selectedIndex == index,
        validated: hasValidatedAnswer,
        isCorrect: hasValidatedAnswer && index == correctIndex,
        isWrong:
            hasValidatedAnswer &&
            selectedIndex == index &&
            selectedIndex != correctIndex,
        onTap: hasValidatedAnswer ? null : () => onSelect(index, options),
        compact: compact,
        reserveCaption: reserveCaption,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuestionCard(
          label: 'Question',
          question: card.question,
          hint: card.hint,
        ),
        SizedBox(height: compact ? 10 : AppSpacing.lg),
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
                      child: tile(index, reserveCaption: true),
                    ),
                ],
              );
            },
          )
        else
          for (var index = 0; index < options.length; index++) ...[
            tile(index),
            const SizedBox(height: 10),
          ],
        if (hasValidatedAnswer && showInlineFeedback) ...[
          const SizedBox(height: AppSpacing.sm),
          _FeedbackCard(
            resultIsCorrect: answeredCorrectly,
            label: answeredCorrectly ? 'Bonne réponse' : 'Réponse attendue',
            answer: card.correctAnswer,
            explanation: card.explanation,
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
    this.validated = false,
    this.shortcutLabel,
    this.compact = false,
    this.reserveCaption = false,
  });

  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final bool validated;
  final VoidCallback? onTap;
  final String? shortcutLabel;
  final bool compact;

  /// Garde la place de la légende « Ta réponse » (grille à hauteur fixe).
  final bool reserveCaption;

  static const double _padding = 18;
  static const double _borderWidth = 1;
  static const double _captionGap = 2;

  static double _captionHeight(BuildContext context) {
    // Mesuré (et non calculé) : la hauteur de ligne réelle est arrondie.
    final painter = TextPainter(
      text: TextSpan(
        text: 'Ta réponse',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  /// Hauteur commune à toutes les bulles d'une grille : celle de l'option la
  /// plus longue (plus la légende « Ta réponse »), pour que la grille reste
  /// régulière quel que soit le texte et ne bouge pas à la validation.
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
    return tallest +
        _captionGap +
        _captionHeight(context) +
        (_padding + _borderWidth) * 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isChosen = validated && isSelected;
    final isQuiet = validated && !isCorrect && !isWrong;
    final borderColor = isCorrect
        ? AppColors.resultGood
        : isWrong
        ? AppColors.resultBad
        : isSelected
        ? scheme.primary
        : theme.dividerColor;
    final background = isCorrect
        ? AppColors.resultGoodSoft
        : isWrong
        ? AppColors.resultBadSoft
        : isSelected
        ? AppColors.primarySoft
        : theme.cardTheme.color ?? scheme.surface;
    final foreground = isCorrect
        ? AppColors.resultGoodText
        : isWrong
        ? AppColors.resultBadText
        : isQuiet
        ? scheme.onSurfaceVariant
        : scheme.onSurface;
    final badgeColor = isSelected && !validated
        ? scheme.primary.withValues(alpha: 0.2)
        : foreground.withValues(alpha: 0.10);
    final status = [
      if (isCorrect) 'bonne réponse',
      if (isWrong) 'mauvaise réponse',
      if (isChosen) 'ta réponse',
    ];
    final base = shortcutLabel == null ? text : '$shortcutLabel. $text';
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final Widget caption = isChosen
        ? Padding(
            padding: const EdgeInsets.only(top: _captionGap),
            child: Text(
              'Ta réponse',
              style: theme.textTheme.bodySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : reserveCaption
        ? SizedBox(height: _captionGap + _captionHeight(context))
        : const SizedBox.shrink();

    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: isSelected,
      label: status.isEmpty ? base : '$base, ${status.join(', ')}',
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        enabled: onTap != null,
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          curve: AppMotion.standardCurve,
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppTheme.radiusButton,
            border: Border.all(color: borderColor, width: _borderWidth),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppTheme.radiusButton,
              child: Padding(
                padding: EdgeInsets.all(compact ? 12 : _padding),
                child: Row(
                  children: [
                    if (shortcutLabel != null) ...[
                      Container(
                        width: compact ? 28 : 32,
                        height: compact ? 28 : 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          shortcutLabel!,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: foreground,
                          ),
                        ),
                      ),
                      SizedBox(width: compact ? 10 : 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            text,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: foreground,
                            ),
                          ),
                          if (reduceMotion || reserveCaption)
                            caption
                          else
                            AnimatedSize(
                              duration: AppMotion.fast,
                              curve: AppMotion.standardCurve,
                              alignment: Alignment.topLeft,
                              child: caption,
                            ),
                        ],
                      ),
                    ),
                    if (isCorrect)
                      Icon(
                        Icons.check_circle_rounded,
                        color: foreground,
                        size: 22,
                      )
                    else if (isWrong)
                      Icon(Icons.cancel_rounded, color: foreground, size: 22),
                  ],
                ),
              ),
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final promptStyle =
        theme.textTheme.headlineSmall?.copyWith(height: 1.5) ??
        theme.textTheme.titleLarge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuestionCard(
          label: 'Question',
          question: prompt,
          hint: hint,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _ClozeBlankChip(
                              gapNumber: token.gapIndex! + 1,
                              text: selectedWords[token.gapIndex!] ?? '_____',
                              isActive:
                                  !hasValidated &&
                                  activeGapIndex == token.gapIndex,
                              isFilled: selectedWords[token.gapIndex!] != null,
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
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Appuie sur un trou puis sur un mot de la banque.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
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
              ],
            ),
          ),
        ),
        if (hasValidated && showInlineFeedback) ...[
          const SizedBox(height: AppSpacing.lg),
          _FeedbackCard(
            resultIsCorrect: isCorrect,
            label: isCorrect == true ? 'Bien joué' : 'Texte complété',
            answer: solutionText,
            explanation: explanation,
          ),
        ],
      ],
    );
  }
}

class _ClozeBlankChip extends StatelessWidget {
  const _ClozeBlankChip({
    required this.gapNumber,
    required this.text,
    required this.isActive,
    required this.isFilled,
    required this.isValidated,
    required this.isCorrect,
    required this.onTap,
  });

  final int gapNumber;
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
        ? (isCorrect == true ? AppColors.resultGood : AppColors.resultBad)
        : isActive
        ? theme.colorScheme.primary
        : isFilled
        ? theme.colorScheme.primary.withValues(alpha: 0.55)
        : theme.dividerColor;
    final background = isValidated
        ? (isCorrect == true
              ? AppColors.resultGoodSoft
              : AppColors.resultBadSoft)
        : isActive
        ? theme.colorScheme.primary.withValues(alpha: 0.14)
        : isFilled
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surface;
    final foreground = isValidated
        ? (isCorrect == true
              ? AppColors.resultGoodText
              : AppColors.resultBadText)
        : isFilled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    final verdict = !isValidated
        ? ''
        : isCorrect == true
        ? ', bonne réponse'
        : ', mauvaise réponse';

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: 'Trou $gapNumber, ${isFilled ? text : 'vide'}$verdict',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.radiusSm,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppTheme.radiusSm,
            border: Border.all(color: borderColor),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 76, minHeight: 44),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                  if (isValidated) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      isCorrect == true
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 16,
                      color: foreground,
                    ),
                  ],
                ],
              ),
            ),
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
    return Pressable(
      enabled: onTap != null,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: text,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.radiusPill,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: enabled
                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: AppTheme.radiusPill,
              border: Border.all(
                color: enabled
                    ? theme.colorScheme.primary.withValues(alpha: 0.25)
                    : theme.dividerColor,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: enabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
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
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = _ResultTone.of(theme, isCorrect);
    OutlineInputBorder border() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: tone.border),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuestionCard(
          label: title,
          question: prompt,
          hint: hint,
          body: TextField(
            controller: controller,
            enabled: !hasValidated,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => onSubmit(),
            style: hasValidated
                ? theme.textTheme.bodyLarge?.copyWith(color: tone.text)
                : null,
            decoration: InputDecoration(
              hintText: 'Ta réponse',
              enabledBorder: hasValidated ? border() : null,
              disabledBorder: hasValidated ? border() : null,
              suffixIcon: hasValidated
                  ? Icon(
                      isCorrect == true
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: tone.text,
                      semanticLabel: isCorrect == true
                          ? 'Bonne réponse'
                          : 'Mauvaise réponse',
                    )
                  : null,
            ),
          ),
        ),
        if (hasValidated && showInlineFeedback) ...[
          const SizedBox(height: AppSpacing.lg),
          _FeedbackCard(
            resultIsCorrect: isCorrect,
            label: isCorrect == true ? 'Bien joué' : answerLabel,
            answer: answerText,
            explanation: explanation,
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
    final answeredCorrectly = selectedIndex == correctIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuestionCard(
          label: 'Question',
          question: card.question,
          hint: card.hint,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Petit séparateur visuel entre la question et la réponse
              // proposée (volontairement plus court que la ligne pleine).
              Container(
                width: 44,
                height: 3,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: AppTheme.radiusPill,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionLabel('Cette réponse est-elle correcte ?'),
              const SizedBox(height: AppSpacing.md),
              Text(proposition, style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final item in [('Vrai', 0), ('Faux', 1)]) ...[
          _McqOptionTile(
            text: item.$1,
            isSelected: selectedIndex == item.$2,
            validated: hasValidatedAnswer,
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
          const SizedBox(height: AppSpacing.md),
          _FeedbackCard(
            resultIsCorrect: answeredCorrectly,
            label: 'Réponse correcte',
            answer: card.correctAnswer,
            explanation: card.explanation,
          ),
        ],
      ],
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final meta = switch (level) {
      1 => ('Basique', Icons.visibility_rounded),
      2 => ('Intermédiaire', Icons.auto_awesome_mosaic_rounded),
      3 => ('Actif', Icons.bolt_rounded),
      _ => ('Avancé', Icons.psychology_alt_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.$2, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${meta.$1}, Niv. $level',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyProgressHeader extends StatelessWidget {
  const _StudyProgressHeader({
    required this.title,
    required this.currentIndex,
    required this.total,
    required this.level,
    required this.progressDots,
    this.onClose,
  });

  final String title;
  final int currentIndex;
  final int total;
  final int level;
  final int progressDots;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    // Clavier ouvert : la seconde ligne cède la place au champ de saisie.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final secondRow = keyboardOpen
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Text('${currentIndex + 1}/$total'),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _LevelBadge(level: level),
                  ),
                ),
                Row(
                  children: List.generate(
                    progressDots,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        color: index <= currentIndex
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Quitter la session',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 12),
        ProgressPill(value: total == 0 ? 0 : (currentIndex + 1) / total),
        // AnimatedSize assert quand la durée est nulle : on le saute alors.
        if (MediaQuery.disableAnimationsOf(context))
          secondRow
        else
          AnimatedSize(
            duration: AppMotion.standard,
            curve: AppMotion.standardCurve,
            alignment: Alignment.topCenter,
            child: secondRow,
          ),
      ],
    );
  }
}

class _ReviewButton extends StatelessWidget {
  const _ReviewButton({
    required this.result,
    required this.onPressed,
    this.isSuggested = false,
    this.compact = false,
  });

  final ReviewResult result;
  final VoidCallback? onPressed;
  final bool isSuggested;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tone = result.tone;
    final background = result.background;
    final borderColor = isSuggested ? tone : Colors.transparent;

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(compact ? 72 : 88),
        padding: EdgeInsets.all(compact ? 12 : 16),
        backgroundColor: background,
        foregroundColor: tone,
        disabledBackgroundColor: background.withValues(alpha: 0.55),
        disabledForegroundColor: tone.withValues(alpha: 0.55),
        elevation: 0,
        tapTargetSize: MaterialTapTargetSize.padded,
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor, width: isSuggested ? 1.5 : 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: compact ? 15 : null,
              color: tone,
            ),
          ),
          SizedBox(height: compact ? 3 : 6),
          Text(
            result.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: compact ? 11 : null,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

extension _ReviewResultColors on ReviewResult {
  Color get tone => switch (this) {
    ReviewResult.again => AppColors.error,
    ReviewResult.hard => AppColors.ratingHard,
    ReviewResult.good => AppColors.resultGood,
    ReviewResult.easy => AppColors.ratingEasy,
  };

  Color get background => switch (this) {
    ReviewResult.again => AppColors.resultBadSoft,
    ReviewResult.hard => AppColors.primarySoft,
    ReviewResult.good => AppColors.resultGoodSoft,
    ReviewResult.easy => AppColors.ratingEasySoft,
  };
}
