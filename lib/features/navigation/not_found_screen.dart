import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, this.requestedPath});

  final String? requestedPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = requestedPath?.trim();

    return AppScaffold(
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: AppTheme.radiusMd,
                      ),
                      child: Icon(
                        Icons.explore_off_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('Erreur 404'),
                          const SizedBox(height: 6),
                          Text(
                            'Page introuvable',
                            style: theme.textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Cette page n’existe pas ou n’est plus disponible.',
                  style: theme.textTheme.bodyLarge,
                ),
                if (path != null && path.isNotEmpty && path != '/') ...[
                  const SizedBox(height: 10),
                  Text(
                    'Chemin demandé: $path',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Retour à l’accueil'),
                    ),
                    FilledButton.tonal(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          context.pop();
                          return;
                        }
                        context.go('/');
                      },
                      child: const Text('Page précédente'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
