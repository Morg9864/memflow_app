import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../../domain/services/card_mode_service.dart';
import '../../widgets/ui.dart';

/// Shows a responsive mode picker.
/// Returns the chosen [TestMode], or null for random.
/// Returns nothing (pop with no value) if the user dismisses.
Future<ModeChoice?> showModeSelectionSheet(
  BuildContext context, {
  StudyModeAvailability? availability,
}) {
  final isDesktop = MediaQuery.sizeOf(context).width >= 720;
  if (isDesktop) {
    return showDialog<ModeChoice>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ModeSelectionDialog(availability: availability),
    );
  }

  return showModalBottomSheet<ModeChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => _ModeSelectionBottomSheet(availability: availability),
  );
}

class ModeChoice {
  const ModeChoice({this.mode});
  // null = random
  final TestMode? mode;
}

class _ModeSelectionDialog extends StatelessWidget {
  const _ModeSelectionDialog({this.availability});

  final StudyModeAvailability? availability;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height - 64;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760, maxHeight: maxHeight),
        child: _ModeSelectionBody(isDialog: true, availability: availability),
      ),
    );
  }
}

class _ModeSelectionBottomSheet extends StatelessWidget {
  const _ModeSelectionBottomSheet({this.availability});

  final StudyModeAvailability? availability;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: _ModeSelectionBody(isDialog: false, availability: availability),
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

class _ModeGroup {
  const _ModeGroup(this.label, this.options);

  final String label;
  final List<_ModeOptionData> options;
}

const _adaptive = _ModeOptionData(
  icon: Icons.auto_awesome_rounded,
  label: 'Adaptatif',
  description: 'Le mode suit ta progression sur chaque carte',
);

const _groups = <_ModeGroup>[
  _ModeGroup('Reconnaître', [
    _ModeOptionData(
      icon: Icons.format_list_numbered_rounded,
      label: 'QCM',
      description: 'Choisis parmi plusieurs réponses',
      mode: TestMode.multipleChoice,
    ),
    _ModeOptionData(
      icon: Icons.check_circle_outline_rounded,
      label: 'Vrai / Faux',
      description: 'Décide si l\'affirmation est correcte',
      mode: TestMode.trueFalse,
    ),
  ]),
  _ModeGroup('Retourner', [
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
  ]),
  _ModeGroup('Se souvenir', [
    _ModeOptionData(
      icon: Icons.edit_rounded,
      label: 'Saisie libre',
      description: 'Écris la réponse de mémoire',
      mode: TestMode.freeText,
    ),
    _ModeOptionData(
      icon: Icons.text_fields_rounded,
      label: 'Texte à trous',
      description: 'Place les mots dans les trous',
      mode: TestMode.cloze,
    ),
  ]),
];

class _ModeSelectionBody extends StatelessWidget {
  const _ModeSelectionBody({required this.isDialog, this.availability});

  final bool isDialog;
  final StudyModeAvailability? availability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final horizontalPadding = isDialog ? 28.0 : 24.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = isDialog || constraints.maxWidth >= 640;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            isDialog ? 28 : 4,
            horizontalPadding,
            20,
          ),
          child: Column(
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
              else
                _ModeHeader(theme: theme),
              const SizedBox(height: 20),
              _ModeRow(
                option: _adaptive,
                availability: availability,
                featured: true,
              ),
              for (final group in _groups) ...[
                const SizedBox(height: 20),
                SectionLabel(group.label),
                const SizedBox(height: 8),
                if (twoColumns)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, option) in group.options.indexed) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: _ModeRow(
                              option: option,
                              availability: availability,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  for (final (i, option) in group.options.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _ModeRow(option: option, availability: availability),
                  ],
              ],
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
        Semantics(
          header: true,
          child: Text('Mode de session', style: theme.textTheme.titleLarge),
        ),
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

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.option,
    this.availability,
    this.featured = false,
  });

  final _ModeOptionData option;
  final StudyModeAvailability? availability;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final compatible = option.mode == null
        ? availability?.total
        : availability?.count(option.mode!);
    final disabled = option.mode != null && compatible == 0;
    final count = compatible == null
        ? null
        : option.mode == null
        ? '$compatible cartes'
        : '$compatible / ${availability!.total} compatibles';
    final onTap = disabled
        ? null
        : () => Navigator.pop(context, ModeChoice(mode: option.mode));
    final muted = scheme.onSurfaceVariant;

    return Pressable(
      enabled: !disabled,
      child: Semantics(
        button: true,
        enabled: !disabled,
        label: [option.label, option.description, ?count].join(', '),
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: disabled
              ? scheme.surfaceContainerHighest
              : featured
              ? scheme.secondaryContainer
              : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(featured ? 24 : 18),
            side: featured || disabled
                ? BorderSide.none
                : BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: EdgeInsets.all(featured ? 18 : 12),
                child: Row(
                  children: [
                    IconTile(
                      icon: disabled ? Icons.lock_outline_rounded : option.icon,
                      size: featured ? 52 : 40,
                      background: featured
                          ? scheme.surface.withValues(alpha: 0.7)
                          : null,
                      foreground: disabled ? muted : null,
                    ),
                    SizedBox(width: featured ? 16 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.label,
                            style:
                                (featured
                                        ? theme.textTheme.titleMedium
                                        : theme.textTheme.titleSmall)
                                    ?.copyWith(
                                      color: disabled
                                          ? muted
                                          : scheme.onSurface,
                                    ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            option.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: disabled
                                  ? muted
                                  : scheme.onSurface.withValues(alpha: 0.78),
                            ),
                          ),
                          if (count != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              count,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: disabled ? muted : scheme.onSurface,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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
