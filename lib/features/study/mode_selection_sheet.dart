import 'package:flutter/material.dart';

import '../../domain/models/models.dart';

/// Shows a bottom sheet letting the user pick a study mode.
/// Returns the chosen [TestMode], or null for random.
/// Returns nothing (pop with no value) if the user dismisses.
Future<ModeChoice?> showModeSelectionSheet(BuildContext context) {
  return showModalBottomSheet<ModeChoice>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ModeSelectionSheet(),
  );
}

class ModeChoice {
  const ModeChoice({this.mode});
  // null = random
  final TestMode? mode;
}

class _ModeSelectionSheet extends StatelessWidget {
  const _ModeSelectionSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Mode de session', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Comment veux-tu être interrogé ?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _ModeOption(
              icon: Icons.shuffle_rounded,
              label: 'Aléatoire',
              description: 'Tous les modes en rotation',
              onTap: () => Navigator.pop(context, const ModeChoice(mode: null)),
            ),
            const Divider(height: 1),
            _ModeOption(
              icon: Icons.format_list_numbered_rounded,
              label: 'QCM',
              description: 'Choisis parmi plusieurs réponses',
              onTap: () => Navigator.pop(
                context,
                const ModeChoice(mode: TestMode.multipleChoice),
              ),
            ),
            _ModeOption(
              icon: Icons.flip_rounded,
              label: 'Flashcard',
              description: 'Retourne la carte pour voir la réponse',
              onTap: () => Navigator.pop(
                context,
                const ModeChoice(mode: TestMode.classicFlashcard),
              ),
            ),
            _ModeOption(
              icon: Icons.swap_horiz_rounded,
              label: 'Flashcard inversée',
              description: 'La réponse est la question',
              onTap: () => Navigator.pop(
                context,
                const ModeChoice(mode: TestMode.reversedFlashcard),
              ),
            ),
            _ModeOption(
              icon: Icons.edit_rounded,
              label: 'Saisie libre',
              description: 'Écris la réponse de mémoire',
              onTap: () => Navigator.pop(
                context,
                const ModeChoice(mode: TestMode.freeText),
              ),
            ),
            _ModeOption(
              icon: Icons.check_circle_outline_rounded,
              label: 'Vrai / Faux',
              description: 'Décide si l\'affirmation est correcte',
              onTap: () => Navigator.pop(
                context,
                const ModeChoice(mode: TestMode.trueFalse),
              ),
            ),
            _ModeOption(
              icon: Icons.text_fields_rounded,
              label: 'Texte à trous',
              description: 'Complète les mots manquants',
              onTap: () => Navigator.pop(
                context,
                const ModeChoice(mode: TestMode.cloze),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleSmall),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
