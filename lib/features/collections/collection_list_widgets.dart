import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

/// En-tête commun des listes paginées: retour, synchronisation, titre complet,
/// sous-titre et nombre de cartes.
class ListScreenHeader extends StatelessWidget {
  const ListScreenHeader({
    super.key,
    required this.title,
    required this.backFallback,
    this.subtitle,
    this.count,
  });

  final String title;
  final String? subtitle;
  final String backFallback;

  /// Nombre total de cartes; masqué tant qu'il est inconnu.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => popOrGo(context, backFallback),
              tooltip: 'Retour',
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const Spacer(),
            const SyncNowButton(),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(title, style: theme.textTheme.displaySmall),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (count != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$count carte${count == 1 ? '' : 's'}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class PaginationFooter extends StatelessWidget {
  const PaginationFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement',
      child: const Column(
        children: [
          SkeletonBox(height: 84, radius: AppTheme.radiusMd),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 84, radius: AppTheme.radiusMd),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 84, radius: AppTheme.radiusMd),
        ],
      ),
    );
  }
}
