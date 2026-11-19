import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

class StudyScopePickerScreen extends ConsumerWidget {
  const StudyScopePickerScreen({super.key, this.collectionId});

  final String? collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (collectionId == null) {
      final collections = ref.watch(studyCollectionsProvider);
      return _PickerScaffold(
        title: 'Que souhaitez-vous réviser ?',
        description: 'Choisissez une collection pour préparer une session.',
        child: collections.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const EmptyState(
            title: 'Collections indisponibles',
            message: 'Impossible de charger les collections pour le moment.',
          ),
          data: (items) {
            final available = items
                .where((item) => !item.isDisabled && item.totalCards > 0)
                .toList();
            if (available.isEmpty) {
              return const EmptyState(
                title: 'Aucune collection à réviser',
                message: 'Importe un fichier CSV pour ajouter des cartes.',
              );
            }
            return Column(
              children: [
                for (final collection in available)
                  _ScopeTile(
                    title: collection.name,
                    detail: 'Collection · ${collection.totalCards} cartes',
                    icon: Icons.library_books_outlined,
                    onTap: () => context.go(
                      '/study?collectionId=${Uri.encodeComponent(collection.id)}&chooseDeck=1',
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    final decks = ref.watch(studyDecksForCollectionProvider(collectionId!));
    final collection = ref
        .watch(studyCollectionsProvider)
        .maybeWhen(
          data: (items) =>
              items.where((item) => item.id == collectionId).firstOrNull,
          orElse: () => null,
        );
    return _PickerScaffold(
      title: collection?.name ?? 'Choisir un deck',
      description: 'Choisissez un deck ou révisez-les tous.',
      onBack: () => context.go('/study'),
      child: decks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(
          title: 'Decks indisponibles',
          message: 'Impossible de charger les decks pour le moment.',
        ),
        data: (items) {
          final available = items
              .where((item) => !item.isDisabled && item.totalCards > 0)
              .toList();
          if (available.isEmpty) {
            return const EmptyState(
              title: 'Aucun deck à réviser',
              message: 'Cette collection ne contient aucune carte disponible.',
            );
          }
          return Column(
            children: [
              _ScopeTile(
                title: 'Tous les decks',
                detail:
                    'Collection · ${available.fold<int>(0, (sum, deck) => sum + deck.totalCards)} cartes',
                icon: Icons.library_books_outlined,
                onTap: () => context.go(
                  '/study?collectionId=${Uri.encodeComponent(collectionId!)}',
                ),
              ),
              for (final deck in available)
                _ScopeTile(
                  title: deck.name,
                  detail: '${deck.totalCards} cartes',
                  icon: Icons.layers_outlined,
                  onTap: () => context.go(
                    '/study?collectionId=${Uri.encodeComponent(collectionId!)}&deckId=${Uri.encodeComponent(deck.id)}',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PickerScaffold extends StatelessWidget {
  const _PickerScaffold({
    required this.title,
    required this.description,
    required this.child,
    this.onBack,
  });

  final String title;
  final String description;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  sliver: SliverList.list(
                    children: [
                      if (onBack != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Toutes les collections'),
                          ),
                        ),
                      Text(
                        'SESSION D’ÉTUDE',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(title, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(description, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: AppSpacing.xl),
                      child,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({
    required this.title,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        minVerticalPadding: AppSpacing.md,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Icon(icon),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(detail),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onTap,
      ),
    );
  }
}
