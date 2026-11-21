import 'package:memflow/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../planning/planning_screen.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../../domain/models/models.dart';

class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({super.key, required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final counts = summary.reviewCounts;
    final planning = summary.planningDay == null
        ? null
        : ref.watch(planningOverviewProvider).value;
    final sessionPlan = planning?.todaysPlans
        .where((plan) => plan.id == summary.planId)
        .firstOrNull;
    final remaining = summary.planId == null || sessionPlan != null
        ? planning
              ?.progress(
                collectionId: summary.collectionId,
                deckId: summary.deckId,
                plan: sessionPlan,
              )
              .remaining
        : null;

    // Au-delà d'un texte agrandi, deux colonnes ne tiennent plus: on empile.
    final stack = largeText(context);
    final tiles = <Widget>[
      _CountTile(
        value: counts[ReviewResult.again] ?? 0,
        label: 'encore',
        icon: AppIcons.rotateCcw,
        tone: AppColors.primary,
      ),
      _CountTile(
        value: counts[ReviewResult.hard] ?? 0,
        label: 'difficile',
        icon: AppIcons.clock3,
        tone: AppColors.ratingHard,
      ),
      _CountTile(
        value: counts[ReviewResult.good] ?? 0,
        label: 'correct',
        icon: AppIcons.check,
        tone: AppColors.resultGood,
      ),
      _CountTile(
        value: counts[ReviewResult.easy] ?? 0,
        label: 'facile',
        icon: AppIcons.star,
        tone: AppColors.ratingEasy,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Session terminée',
                      style: theme.textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(summary.deckTitle, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 28),
                  Text(
                    '${summary.correctCount}/${summary.totalCards}',
                    style: theme.textTheme.displayLarge,
                  ),
                  Text(
                    'précision objective',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${summary.totalCards} cartes · ${_formatDuration(summary.duration)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  if (stack)
                    for (final tile in tiles) ...[
                      tile,
                      const SizedBox(height: 8),
                    ]
                  else
                    for (var i = 0; i < tiles.length; i += 2) ...[
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: tiles[i]),
                            const SizedBox(width: 8),
                            Expanded(child: tiles[i + 1]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  _CountTile(
                    value: summary.totalCards,
                    label: 'cartes vues',
                    icon: AppIcons.layers,
                    tone: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 24),
                  if (planning != null &&
                      summary.planningDay == planning.today) ...[
                    StudyFollowUps(
                      planning: planning,
                      collectionId: summary.collectionId,
                      deckId: summary.deckId,
                    ),
                    if (remaining?.isNotEmpty == true)
                      FilledButton.icon(
                        onPressed: () => context.go(
                          plannedStudyLocation(
                            collectionId: summary.collectionId,
                            deckId: summary.deckId,
                            planId: summary.planId,
                          ),
                        ),
                        icon: const Icon(AppIcons.play),
                        label: Text(
                          'Continuer le planning (${remaining!.length})',
                        ),
                      ),
                    TextButton(
                      onPressed: () => context.go(planningLocation()),
                      child: const Text('Voir le planning'),
                    ),
                  ],
                  if (summary.incorrectCardIds.isNotEmpty ||
                      summary.incorrectCount > 0)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      onPressed: () =>
                          context.go('/study/errors', extra: summary),
                      icon: const Icon(AppIcons.rotateCcw),
                      label: Text(
                        'Revoir mes erreurs (${summary.incorrectCount})',
                      ),
                    ),
                  FilledButton(
                    onPressed: () {
                      if (summary.collectionId != null) {
                        context.go('/collection/${summary.collectionId}');
                      } else {
                        context.go('/');
                      }
                    },
                    child: const Text('Retour à la collection'),
                  ),
                  const SizedBox(height: 10),
                  if (summary.planningDay == null)
                    FilledButton.tonal(
                      style: AppTheme.secondaryAction,
                      onPressed: () {
                        final params = summary.deckId != null
                            ? '?deckId=${summary.deckId}'
                            : '?collectionId=${summary.collectionId}';
                        context.go('/study$params');
                      },
                      child: const Text('Refaire une session'),
                    ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Accueil'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDuration(Duration? duration) {
    if (duration == null) return 'durée indisponible';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${minutes}m ${seconds}s';
  }
}

/// Compteur compact: l'icône porte la couleur, le texte reste neutre.
class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.tone,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: tone),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$value', style: theme.textTheme.titleLarge),
                  Text(label, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
