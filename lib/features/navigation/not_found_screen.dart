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

    // Scrollable: large text or a short screen must never overflow.
    return AppScaffold(
      child: Center(
        child: SingleChildScrollView(
          child: EmptyState(
            icon: Icons.explore_off_rounded,
            title: 'Page introuvable',
            message: 'Cette page n’existe pas ou n’est plus disponible.',
            action: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (path != null && path.isNotEmpty && path != '/') ...[
                  Text(
                    'Chemin demandé: $path',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Pressable(
                  child: FilledButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Retour à l’accueil'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonal(
                  style: AppTheme.secondaryAction,
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
          ),
        ),
      ),
    );
  }
}
