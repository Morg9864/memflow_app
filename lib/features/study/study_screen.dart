import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  });

  final String? collectionId;
  final String? deckId;

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  StudySessionState? _state;
  Object? _error;
  bool _submitting = false;
  late final StudyController _controller;
  final TextEditingController _freeTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = StudyController(ref.read(appRepositoryProvider));
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
      );
      if (mounted) {
        setState(() => _state = session);
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
    final isCorrect = _controller.evaluateMultipleChoice(state.currentCard, index, options);
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
    final answer = _freeTextController.text.trim();
    final isCorrect = isCloze
        ? _controller.evaluateCloze(state.currentCard, answer)
        : _controller.evaluateFreeText(state.currentCard, answer);
    setState(() {
      _state = state.copyWith(
        hasValidatedAnswer: true,
        currentAnswerWasCorrect: isCorrect,
        freeTextAnswer: answer,
      );
    });
  }

  Future<void> _applyReview(ReviewResult result) async {
    final state = _state;
    if (state == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      await _controller.submitReview(
        cardId: state.currentCard.id,
        result: result,
        wasCorrect: state.currentAnswerWasCorrect ?? result != ReviewResult.again,
      );
      final nextState = _controller.advance(state, result);
      if (!mounted) return;
      if (nextState.isCompleted) {
        context.go('/session-summary', extra: _controller.buildSummary(nextState));
        return;
      }
      _freeTextController.clear();
      setState(() => _state = nextState);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
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
        widget.collectionId ?? _state?.collectionId ?? _state?.currentCard.collectionId;
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
              message: _error.toString(),
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
    final suggested = _controller.suggestedResult(state.currentAnswerWasCorrect);
    final options = mode == TestMode.multipleChoice ? card.buildOptions() : const <String>[];

    return PopScope(
      canPop: _canPopStudy(),
      onPopInvokedWithResult: (didPop, _) => _handlePopInvoked(didPop),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! < -200 &&
                      !state.revealed &&
                      (mode == TestMode.classicFlashcard || mode == TestMode.reversedFlashcard)) {
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
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: switch (mode) {
                          TestMode.multipleChoice => _McqMode(
                              key: ValueKey('mcq-${card.id}-${state.hasValidatedAnswer}'),
                              card: card,
                              options: options,
                              selectedIndex: state.selectedOptionIndex,
                              hasValidatedAnswer: state.hasValidatedAnswer,
                              onSelect: _selectOption,
                            ),
                          TestMode.cloze => _TextEntryMode(
                              key: ValueKey('cloze-${card.id}-${state.hasValidatedAnswer}'),
                              title: 'Texte à trous',
                              prompt: _controller.buildClozePrompt(card),
                              hint: card.hint,
                              controller: _freeTextController,
                              hasValidated: state.hasValidatedAnswer,
                              isCorrect: state.currentAnswerWasCorrect,
                              answerLabel: 'Réponse attendue',
                              answerText: card.correctAnswer,
                              explanation: card.explanation,
                              actionLabel: 'Valider ma réponse',
                              onSubmit: () => _submitTextAnswer(isCloze: true),
                            ),
                          TestMode.freeText => _TextEntryMode(
                              key: ValueKey('free-${card.id}-${state.hasValidatedAnswer}'),
                              title: 'Saisie libre',
                              prompt: card.question,
                              hint: card.hint,
                              controller: _freeTextController,
                              hasValidated: state.hasValidatedAnswer,
                              isCorrect: state.currentAnswerWasCorrect,
                              answerLabel: 'Réponse',
                              answerText: card.correctAnswer,
                              explanation: card.explanation,
                              actionLabel: 'Vérifier',
                              onSubmit: () => _submitTextAnswer(isCloze: false),
                            ),
                          TestMode.trueFalse => _TrueFalseMode(
                              key: ValueKey('tf-${card.id}-${state.hasValidatedAnswer}'),
                              card: card,
                              selectedIndex: state.selectedOptionIndex,
                              hasValidatedAnswer: state.hasValidatedAnswer,
                              onSelect: (index) {
                                final correct = _isTrueFalseSelectionCorrect(card, index);
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
                              onReveal: _reveal,
                            ),
                          },
                        ),
                      ),
                      if (_needsReviewButtons(mode, state)) ...[
                        const SizedBox(height: 18),
                        const SectionLabel('Comment tu t’en es sorti ?'),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
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
                                enabled: !_submitting,
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

class _FlashcardMode extends StatelessWidget {
  const _FlashcardMode({
    super.key,
    required this.card,
    required this.revealed,
    required this.reversed,
    required this.onReveal,
  });

  final StudyCard card;
  final bool revealed;
  final bool reversed;
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
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 28),
            Text('Glisse vers le haut', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onReveal,
              child: const Text('Révéler la réponse'),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Question'),
            const SizedBox(height: 12),
            Text(reversed ? card.correctAnswer : card.question,
                style: Theme.of(context).textTheme.titleLarge),
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
              Text(card.explanation!, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ],
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
    required this.onSelect,
  });

  final StudyCard card;
  final List<String> options;
  final int? selectedIndex;
  final bool hasValidatedAnswer;
  final void Function(int index, List<String> options) onSelect;

  @override
  Widget build(BuildContext context) {
    final correctIndex = options.indexWhere((item) => item == card.correctAnswer);
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
                Text(card.question, style: Theme.of(context).textTheme.headlineMedium),
                if (card.hint != null) ...[
                  const SizedBox(height: 16),
                  Text(card.hint!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < options.length; index++) ...[
          _McqOptionTile(
            text: options[index],
            isSelected: selectedIndex == index,
            isCorrect: hasValidatedAnswer && index == correctIndex,
            isWrong: hasValidatedAnswer && selectedIndex == index && selectedIndex != correctIndex,
            onTap: hasValidatedAnswer ? null : () => onSelect(index, options),
          ),
          const SizedBox(height: 10),
        ],
        if (hasValidatedAnswer) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(selectedIndex == correctIndex ? 'Bonne réponse' : 'Réponse attendue'),
                  const SizedBox(height: 10),
                  Text(card.correctAnswer, style: Theme.of(context).textTheme.titleLarge),
                  if (card.explanation != null) ...[
                    const SizedBox(height: 14),
                    Text(card.explanation!, style: Theme.of(context).textTheme.bodyLarge),
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
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
  final String actionLabel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final feedbackTone = isCorrect == true ? const Color(0xFF245433) : const Color(0xFF8E2F24);
    final feedbackBackground =
        isCorrect == true ? const Color(0xFFEAF3E7) : const Color(0xFFFBE7E4);

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
                  Text(hint!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
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
        if (hasValidated) ...[
          const SizedBox(height: 16),
          Card(
            color: feedbackBackground,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (isCorrect == true ? 'Bien joué' : answerLabel).toUpperCase(),
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: feedbackTone),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    answerText,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: feedbackTone),
                  ),
                  if (explanation != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      explanation!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: feedbackTone),
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
    required this.selectedIndex,
    required this.hasValidatedAnswer,
    required this.onSelect,
  });

  final StudyCard card;
  final int? selectedIndex;
  final bool hasValidatedAnswer;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    final correctIndex = _trueFalseCorrectIndex(card);

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Vrai / Faux'),
                const SizedBox(height: 14),
                Text(card.question, style: Theme.of(context).textTheme.headlineMedium),
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
                hasValidatedAnswer && selectedIndex == item.$2 && selectedIndex != correctIndex,
            onTap: hasValidatedAnswer ? null : () => onSelect(item.$2),
          ),
          const SizedBox(height: 10),
        ],
        if (hasValidatedAnswer) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Réponse attendue'),
                  const SizedBox(height: 10),
                  Text(card.correctAnswer, style: Theme.of(context).textTheme.titleLarge),
                  if (card.explanation != null) ...[
                    const SizedBox(height: 14),
                    Text(card.explanation!, style: Theme.of(context).textTheme.bodyLarge),
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

bool _isTrueFalseSelectionCorrect(StudyCard card, int index) {
  final normalized = card.correctAnswer.toLowerCase();
  return (index == 0 && (normalized.contains('true') || normalized.contains('vrai'))) ||
      (index == 1 && (normalized.contains('false') || normalized.contains('faux')));
}

int _trueFalseCorrectIndex(StudyCard card) {
  return _isTrueFalseSelectionCorrect(card, 0) ? 0 : 1;
}
