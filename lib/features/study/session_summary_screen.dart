import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../domain/models/models.dart';
import '../../widgets/ui.dart';

class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({super.key, required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session terminée',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        summary.deckTitle,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${summary.totalCards} cartes · ${_formatDuration(summary.duration)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          StatCard(
                            value: '${summary.totalCards}',
                            label: 'cartes vues',
                            icon: Icons.style_rounded,
                          ),
                          StatCard(
                            value:
                                '${summary.reviewCounts[ReviewResult.again] ?? 0}',
                            label: 'encore',
                            icon: Icons.refresh_rounded,
                          ),
                          StatCard(
                            value:
                                '${summary.reviewCounts[ReviewResult.hard] ?? 0}',
                            label: 'difficile',
                            icon: Icons.terrain_rounded,
                          ),
                          StatCard(
                            value:
                                '${summary.reviewCounts[ReviewResult.good] ?? 0}',
                            label: 'correct',
                            icon: Icons.thumb_up_alt_rounded,
                          ),
                          StatCard(
                            value:
                                '${summary.reviewCounts[ReviewResult.easy] ?? 0}',
                            label: 'facile',
                            icon: Icons.rocket_launch_rounded,
                          ),
                          StatCard(
                            value:
                                '${summary.correctCount}/${summary.totalCards}',
                            label: 'précision objective',
                            icon: Icons.insights_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      if (summary.incorrectCount > 0)
                        TextButton.icon(
                          onPressed: () =>
                              context.go('/study/errors', extra: summary),
                          icon: const Icon(Icons.replay_rounded),
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
