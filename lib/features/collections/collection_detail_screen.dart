import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import 'collection_due_cards_screen.dart';
import '../../widgets/ui.dart';

Future<bool> _confirmDeletion(
  BuildContext context,
  String title,
  String message,
) async {
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

final collectionProvider = StreamProvider.family<CollectionListItem?, String>((
  ref,
  collectionId,
) {
  return ref.watch(appRepositoryProvider).watchCollection(collectionId);
});

final collectionDecksProvider =
    StreamProvider.family<List<DeckListItem>, String>((ref, collectionId) {
      return ref
          .watch(appRepositoryProvider)
          .watchDecksForCollection(collectionId);
    });

enum _DeckSortField { importOrder, name }

enum _SortDirection { ascending, descending }

class CollectionDetailScreen extends ConsumerStatefulWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  static const _collectionIcons = [
    '🔢',
    '🧪',
    '🧲',
    '🧬',
    '💻',
    '🌍',
    '🏛️',
    '⚖️',
    '📈',
    '🧠',
    '💬',
    '📚',
    '🗣️',
    '🎨',
    '🎬',
    '🎵',
    '🩺',
    '🏃',
    '🌿',
    '🛠️',
  ];

  bool _busy = false;
  _DeckSortField _deckSortField = _DeckSortField.importOrder;
  _SortDirection _deckSortDirection = _SortDirection.ascending;

  List<DeckListItem> _sortedDecks(List<DeckListItem> decks) {
    final sorted = [...decks];
    sorted.sort((a, b) {
      final comparison = switch (_deckSortField) {
        _DeckSortField.importOrder => a.createdAt.compareTo(b.createdAt),
        _DeckSortField.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
      };
      if (comparison != 0) {
        return _deckSortDirection == _SortDirection.ascending
            ? comparison
            : -comparison;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  void _setDeckSort(_DeckSortField field, _SortDirection direction) {
    setState(() {
      _deckSortField = field;
      _deckSortDirection = direction;
    });
  }

  Future<void> _chooseCollectionIcon(CollectionListItem collection) async {
    final selectedIcon = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choisir une icône'),
        content: SizedBox(
          width: 320,
          child: GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final icon in _collectionIcons)
                Semantics(
                  button: true,
                  selected: icon == collection.icon,
                  label: 'Choisir $icon',
                  child: Tooltip(
                    message: 'Choisir $icon',
                    child: InkWell(
                      onTap: () => Navigator.of(dialogContext).pop(icon),
                      borderRadius: BorderRadius.circular(8),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: icon == collection.icon
                              ? Theme.of(
                                  dialogContext,
                                ).colorScheme.primaryContainer
                              : Theme.of(dialogContext).colorScheme.surface,
                          border: Border.all(
                            color: icon == collection.icon
                                ? Theme.of(dialogContext).colorScheme.primary
                                : Theme.of(
                                    dialogContext,
                                  ).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 25),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
    if (selectedIcon == null || selectedIcon == collection.icon || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(appRepositoryProvider)
          .setCollectionIcon(collection.id, selectedIcon);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Icône de "${collection.name}" mise à jour')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _launchStudy({String? deckId}) async {
    if (deckId != null) {
      context.push('/study?deckId=$deckId');
    } else {
      context.push('/study?collectionId=${widget.collectionId}');
    }
  }

  Future<void> _deleteCollection(CollectionListItem item) async {
    final ok = await _confirmDeletion(
      context,
      'Supprimer "${item.name}" ?',
      'Cette collection, tous ses decks et ses ${item.totalCards} cartes seront supprimés définitivement.',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(appRepositoryProvider)
          .deleteCollection(widget.collectionId);
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

  Future<void> _toggleDeckDisabled(DeckListItem deck) async {
    final willDisable = !deck.isDisabled;
    setState(() => _busy = true);
    try {
      await ref
          .read(appRepositoryProvider)
          .setDeckDisabled(deck.id, willDisable);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              willDisable
                  ? '"${deck.name}" désactivé'
                  : '"${deck.name}" réactivé',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleCollectionDisabled(CollectionListItem collection) async {
    final willDisable = !collection.isDisabled;
    setState(() => _busy = true);
    try {
      await ref
          .read(appRepositoryProvider)
          .setCollectionDisabled(collection.id, willDisable);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              willDisable
                  ? '"${collection.name}" désactivée'
                  : '"${collection.name}" réactivée',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collection = ref.watch(collectionProvider(widget.collectionId));
    final decks = ref.watch(collectionDecksProvider(widget.collectionId));
    final deckCount = decks.asData?.value.length;
    final currentCollection = collection.asData?.value;

    return AppScaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _busy || currentCollection?.isDisabled != false
            ? null
            : () => _launchStudy(),
        child: const Icon(Icons.play_arrow_rounded),
      ),
      child: collection.when(
        data: (item) {
          if (item == null) {
            return const EmptyState(
              title: 'Collection introuvable',
              message:
                  "Cette collection n'existe pas ou n'est plus disponible.",
            );
          }
          return ListView(
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
                    enabled: !_busy,
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (action) {
                      switch (action) {
                        case _CollectionAction.toggleDisabled:
                          _toggleCollectionDisabled(item);
                        case _CollectionAction.delete:
                          _deleteCollection(item);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: _CollectionAction.toggleDisabled,
                        child: Row(
                          children: [
                            Icon(
                              item.isDisabled
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.isDisabled
                                    ? 'Réactiver la collection'
                                    : 'Désactiver la collection',
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _CollectionAction.delete,
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Theme.of(context).colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Supprimer la collection',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(
                  message: "Changer l'icône",
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const ValueKey('collection-icon'),
                      onTap: _busy ? null : () => _chooseCollectionIcon(item),
                      borderRadius: BorderRadius.circular(22),
                      child: Ink(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Color(item.color).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Center(
                          child: Text(
                            item.icon,
                            style: const TextStyle(fontSize: 30),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  if (item.isDisabled) ...[
                    const SizedBox(width: 12),
                    Chip(
                      avatar: const Icon(
                        Icons.visibility_off_rounded,
                        size: 18,
                      ),
                      label: const Text('Désactivée'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
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
                      value: '${item.cardsDone}',
                      label: 'faites',
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      value: '${item.dueCards}',
                      label: 'à revoir',
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                onPressed: item.isDisabled
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CollectionDueCardsScreen(
                            collectionId: widget.collectionId,
                            collectionName: item.name,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('Voir les échéances'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const SectionLabel('Decks'),
                  const Spacer(),
                  if (deckCount != null) Text('$deckCount decks'),
                  const SizedBox(width: 8),
                  PopupMenuButton<(_DeckSortField, _SortDirection)>(
                    tooltip: 'Trier les decks',
                    icon: const Icon(Icons.sort_rounded),
                    onSelected: (sort) => _setDeckSort(sort.$1, sort.$2),
                    itemBuilder: (_) => [
                      _deckSortMenuItem(
                        context,
                        field: _DeckSortField.importOrder,
                        direction: _SortDirection.ascending,
                        label: 'Importation croissant',
                        icon: Icons.south_rounded,
                      ),
                      _deckSortMenuItem(
                        context,
                        field: _DeckSortField.importOrder,
                        direction: _SortDirection.descending,
                        label: 'Importation décroissant',
                        icon: Icons.north_rounded,
                      ),
                      _deckSortMenuItem(
                        context,
                        field: _DeckSortField.name,
                        direction: _SortDirection.ascending,
                        label: 'Alphabet croissant',
                        icon: Icons.sort_by_alpha_rounded,
                      ),
                      _deckSortMenuItem(
                        context,
                        field: _DeckSortField.name,
                        direction: _SortDirection.descending,
                        label: 'Alphabet décroissant',
                        icon: Icons.sort_by_alpha_rounded,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              decks.when(
                data: (deckItems) {
                  final sortedDecks = _sortedDecks(deckItems);
                  return Column(
                    children: [
                      for (final deck in sortedDecks) ...[
                        DeckCard(
                          deck: deck,
                          onTap: item.isDisabled
                              ? null
                              : () => _launchStudy(deckId: deck.id),
                          onDelete: _busy ? null : () => _deleteDeck(deck),
                          onToggleDisabled: _busy
                              ? null
                              : () => _toggleDeckDisabled(deck),
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
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => Text(error.toString()),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(error.toString()),
      ),
    );
  }

  PopupMenuItem<(_DeckSortField, _SortDirection)> _deckSortMenuItem(
    BuildContext context, {
    required _DeckSortField field,
    required _SortDirection direction,
    required String label,
    required IconData icon,
  }) {
    final selected = _deckSortField == field && _deckSortDirection == direction;
    return PopupMenuItem(
      value: (field, direction),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (selected) ...[
            const SizedBox(width: 12),
            Icon(
              Icons.check_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }
}

enum _CollectionAction { toggleDisabled, delete }
