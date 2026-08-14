import 'package:flutter/material.dart';

import '../../domain/models/models.dart';

/// Shows a responsive mode picker.
/// Returns the chosen [TestMode], or null for random.
/// Returns nothing (pop with no value) if the user dismisses.
Future<ModeChoice?> showModeSelectionSheet(BuildContext context) {
  final isDesktop = MediaQuery.sizeOf(context).width >= 720;
  if (isDesktop) {
    return showDialog<ModeChoice>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _ModeSelectionDialog(),
    );
  }

  return showModalBottomSheet<ModeChoice>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => const _ModeSelectionBottomSheet(),
  );
}

class ModeChoice {
  const ModeChoice({this.mode});
  // null = random
  final TestMode? mode;
}

class _ModeSelectionDialog extends StatelessWidget {
  const _ModeSelectionDialog();

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height - 64;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760, maxHeight: maxHeight),
        child: const _ModeSelectionBody(isDialog: true),
      ),
    );
  }
}

class _ModeSelectionBottomSheet extends StatelessWidget {
  const _ModeSelectionBottomSheet();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      top: false,
      child: _ModeSelectionBody(isDialog: false),
    );
  }
}

class _ModeSelectionBody extends StatelessWidget {
  const _ModeSelectionBody({required this.isDialog});

  final bool isDialog;

  static const _options = <_ModeOptionData>[
    _ModeOptionData(
      icon: Icons.auto_awesome_rounded,
      label: 'Adaptatif',
      description: 'Le mode suit ta progression sur chaque carte',
    ),
    _ModeOptionData(
      icon: Icons.format_list_numbered_rounded,
      label: 'QCM',
      description: 'Choisis parmi plusieurs réponses',
      mode: TestMode.multipleChoice,
    ),
    _ModeOptionData(
      icon: Icons.flip_rounded,
      label: 'Flashcard',
      description: 'Retourne la carte pour voir la réponse',
      mode: TestMode.classicFlashcard,
    ),
    _ModeOptionData(
      icon: Icons.swap_horiz_rounded,
      label: 'Flashcard inversée',
      description: 'La réponse est la question',
      mode: TestMode.reversedFlashcard,
    ),
    _ModeOptionData(
      icon: Icons.edit_rounded,
      label: 'Saisie libre',
      description: 'Écris la réponse de mémoire',
      mode: TestMode.freeText,
    ),
    _ModeOptionData(
      icon: Icons.check_circle_outline_rounded,
      label: 'Vrai / Faux',
      description: 'Décide si l\'affirmation est correcte',
      mode: TestMode.trueFalse,
    ),
    _ModeOptionData(
      icon: Icons.text_fields_rounded,
      label: 'Texte à trous',
      description: 'Place les mots dans les trous',
      mode: TestMode.cloze,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final horizontalPadding = isDialog ? 28.0 : 24.0;
    final topPadding = isDialog ? 28.0 : 20.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = isDialog || constraints.maxWidth >= 640;
        final crossAxisCount = twoColumns ? 2 : 1;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDialog)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _ModeHeader(theme: theme)),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                )
              else ...[
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _ModeHeader(theme: theme),
              ],
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _options.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: twoColumns ? 156 : 148,
                ),
                itemBuilder: (context, index) {
                  final option = _options[index];
                  return _ModeOptionCard(option: option);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeHeader extends StatelessWidget {
  const _ModeHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mode de session', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Comment veux-tu être interrogé ?',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ModeOptionData {
  const _ModeOptionData({
    required this.icon,
    required this.label,
    required this.description,
    this.mode,
  });

  final IconData icon;
  final String label;
  final String description;
  final TestMode? mode;
}

class _ModeOptionCard extends StatelessWidget {
  const _ModeOptionCard({required this.option});

  final _ModeOptionData option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pop(context, ModeChoice(mode: option.mode)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      option.icon,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        option.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
