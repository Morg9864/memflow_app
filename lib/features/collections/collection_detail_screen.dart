import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/ui.dart';

Future<bool> _confirmDeletion(BuildContext context, String title, String message) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

final collectionProvider =
    StreamProvider.family<CollectionListItem?, String>((ref, collectionId) {
  return ref.watch(appRepositoryProvider).watchCollection(collectionId);
});

final collectionDecksProvider =
    StreamProvider.family<List<DeckListItem>, String>((ref, collectionId) {
  return ref.watch(appRepositoryProvider).watchDecksForCollection(collectionId);
});

class CollectionDetailScreen extends ConsumerStatefulWidget {
  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
  });

  final String collectionId;

  @override
  ConsumerState<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends ConsumerState<CollectionDetailScreen> {
  bool _busy = false;

  Future<void> _deleteCollection(CollectionListItem item) async {
    final ok = await _confirmDeletion(
      context,
      'Supprimer "${item.name}" ?',
      'Cette collection, tous ses decks et ses ${item.totalCards} cartes seront supprimés définitivement.',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(appRepositoryProvider).deleteCollection(widget.collectionId);
      if (mounted) context.go('/');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteDeck(DeckListItem deck) async {
    final ok = await _confirmDeletion(
      context,
      'Supprimer "${deck.name}" ?',
      'Ce deck et ses ${deck.totalCards} cartes seront supprimés définitivement.',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(appRepositoryProvider).deleteDeck(deck.id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collection = ref.watch(collectionProvider(widget.collectionId));
    final decks = ref.watch(collectionDecksProvider(widget.collectionId));
    final deckCount = decks.asData?.value.length;

    return AppScaffold(
      floatingActionButton: FloatingActionButton(
        onPressed:
            _busy ? null : () => context.push('/study?collectionId=${widget.collectionId}'),
        child: const Icon(Icons.play_arrow_rounded),
      ),
      child: collection.when(
        data: (item) {
          if (item == null) {
            return const EmptyState(
              title: 'Collection introuvable',
              message: "Cette collection n'existe pas ou n'est plus disponible.",
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                  const ThemeToggleButton(),
                  PopupMenuButton<_CollectionAction>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (action) {
                      if (action == _CollectionAction.delete) {
                        _deleteCollection(item);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: _CollectionAction.delete,
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                color: Theme.of(context).colorScheme.error, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              'Supprimer la collection',
                              style:
                                  TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Color(item.color).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Text(item.icon, style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(height: 18),
              Text(item.name, style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(item.description, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      value: '${item.totalCards}',
                      label: 'cartes',
                      icon: Icons.style_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      value: '${(item.masteredPercentage * 100).round()}%',
                      label: 'maîtrise',
                      icon: Icons.stars_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      value: '${item.dueCards}',
                      label: 'dues',
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const SectionLabel('Decks'),
                  const Spacer(),
                  Text(deckCount == null ? '' : '$deckCount packs'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: decks.when(
                  data: (deckItems) => ListView(
                    children: [
                      for (final deck in deckItems) ...[
                        DeckCard(
                          deck: deck,
                          onTap: () => context.push('/study?deckId=${deck.id}'),
                          onDelete: _busy ? null : () => _deleteDeck(deck),
                          onViewCards: () => context.push(
                            '/deck/${deck.id}/cards?name=${Uri.encodeComponent(deck.name)}',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton.tonalIcon(
                        onPressed: () => context.push('/import'),
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Importer un CSV'),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Text(error.toString()),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(error.toString()),
      ),
    );
  }
}

enum _CollectionAction { delete }
