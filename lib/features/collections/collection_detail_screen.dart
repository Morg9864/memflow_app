import 'package:memflow/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
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
          style: AppTheme.compactAction.merge(
            FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
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

    return AppScaffold(
      child: collection.when(
        data: (item) {
          if (item == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BackBar(),
                Expanded(
                  child: EmptyState(
                    title: 'Collection introuvable',
                    message:
                        "Cette collection n'existe pas ou n'est plus disponible.",
                    action: FilledButton.tonal(
                      style: AppTheme.secondaryAction,
                      onPressed: () => popOrGo(context, '/'),
                      child: const Text("Retour à l'accueil"),
                    ),
                  ),
                ),
              ],
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final inlineStudy =
                  constraints.maxWidth >= AppBreakpoints.tablet &&
                  constraints.maxWidth > constraints.maxHeight;
              final children = <Widget>[
                _BackBar(
                  menu: PopupMenuButton<_CollectionAction>(
                    tooltip: 'Options de la collection',
                    enabled: !_busy,
                    icon: const Icon(AppIcons.ellipsis),
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
                        child: _MenuRow(
                          icon: item.isDisabled
                              ? AppIcons.eye
                              : AppIcons.eyeOff,
                          label: item.isDisabled
                              ? 'Réactiver la collection'
                              : 'Désactiver la collection',
                        ),
                      ),
                      const PopupMenuItem(
                        value: _CollectionAction.delete,
                        child: _MenuRow(
                          icon: AppIcons.trash2,
                          label: 'Supprimer la collection',
                          destructive: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Summary(
                  collection: item,
                  onChangeIcon: _busy
                      ? null
                      : () => _chooseCollectionIcon(item),
                  onStudy: _busy || item.isDisabled
                      ? null
                      : () => _launchStudy(),
                  inlineStudy: inlineStudy,
                  onViewDue: item.isDisabled
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CollectionDueCardsScreen(
                              collectionId: widget.collectionId,
                              collectionName: item.name,
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.md,
                    bottom: AppSpacing.xs,
                  ),
                  child: _DecksHeader(
                    deckCount: decks.asData?.value.length,
                    field: _deckSortField,
                    direction: _deckSortDirection,
                    onSort: _setDeckSort,
                  ),
                ),
                ..._deckEntries(item, decks),
              ];
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      itemCount: children.length,
                      itemBuilder: (context, index) => children[index],
                    ),
                  ),
                  if (!inlineStudy)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: _StudyButton(
                        onPressed: _busy || item.isDisabled
                            ? null
                            : () => _launchStudy(),
                        expanded: true,
                      ),
                    ),
                ],
              );
            },
          );
        },
        loading: () => const _DetailSkeleton(),
        error: (error, stackTrace) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _BackBar(),
            Expanded(
              child: AppErrorState(
                onRetry: () =>
                    ref.invalidate(collectionProvider(widget.collectionId)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _deckEntries(
    CollectionListItem item,
    AsyncValue<List<DeckListItem>> decks,
  ) {
    return decks.when(
      data: (deckItems) {
        if (deckItems.isEmpty) {
          return const [
            EmptyState(
              title: 'Aucun deck',
              message: 'Importe un fichier CSV pour ajouter des decks.',
              action: _ImportButton(),
            ),
          ];
        }
        final activeDecks = _sortedDecks(
          deckItems.where((deck) => !deck.isDisabled).toList(),
        );
        final disabledDecks = _sortedDecks(
          deckItems.where((deck) => deck.isDisabled).toList(),
        );
        // ponytail: bloc unique (non lazy) comme avant; les tests existants
        // supposent tous les decks construits. SliverList.builder par deck si
        // les collections dépassent quelques centaines de decks.
        return [
          LayoutBuilder(
            builder: (context, constraints) {
              // Colonnes selon la largeur disponible et l'échelle du texte.
              final columns = adaptiveColumns(context, constraints.maxWidth);
              List<Widget> rows(List<DeckListItem> list) => [
                for (var i = 0; i < list.length; i += columns)
                  cardRow([
                    for (final deck in list.skip(i).take(columns))
                      _buildDeckCard(item, deck),
                  ], columns),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...rows(activeDecks),
                  if (disabledDecks.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(
                        top: AppSpacing.md,
                        bottom: AppSpacing.md,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SectionLabel('Désactivé(s)'),
                      ),
                    ),
                    ...rows(disabledDecks),
                  ],
                  const _ImportButton(),
                ],
              );
            },
          ),
        ];
      },
      loading: () => const [_DeckSkeletons()],
      error: (error, stackTrace) => [
        AppErrorState(
          onRetry: () =>
              ref.invalidate(collectionDecksProvider(widget.collectionId)),
        ),
      ],
    );
  }

  Widget _buildDeckCard(CollectionListItem collection, DeckListItem deck) {
    return DeckCard(
      deck: deck,
      onTap: collection.isDisabled ? null : () => _launchStudy(deckId: deck.id),
      onDelete: _busy ? null : () => _deleteDeck(deck),
      onToggleDisabled: _busy ? null : () => _toggleDeckDisabled(deck),
      onViewCards: () => context.push(
        '/deck/${deck.id}/cards?name=${Uri.encodeComponent(deck.name)}',
      ),
    );
  }
}

enum _CollectionAction { toggleDisabled, delete }

/// Ligne du haut: retour, synchronisation et menu optionnel.
class _BackBar extends StatelessWidget {
  const _BackBar({this.menu});

  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          IconButton(
            onPressed: () => popOrGo(context, '/'),
            tooltip: 'Retour',
            icon: const Icon(AppIcons.arrowLeft),
          ),
          const Spacer(),
          const SyncNowButton(),
          ?menu,
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            // Rouge d'erreur en texte: 4.2:1 seulement, on prend le ton foncé.
            style: TextStyle(
              color: destructive ? AppColors.resultBadText : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.collection,
    required this.onChangeIcon,
    required this.onStudy,
    required this.inlineStudy,
    required this.onViewDue,
  });

  final CollectionListItem collection;
  final VoidCallback? onChangeIcon;
  final VoidCallback? onStudy;
  final bool inlineStudy;
  final VoidCallback? onViewDue;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _Identity(
                      collection: collection,
                      onChangeIcon: onChangeIcon,
                    ),
                  ),
                  if (inlineStudy) ...[
                    const SizedBox(width: AppSpacing.xl),
                    _StudyButton(onPressed: onStudy),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _CollectionProgress(collection: collection, onViewDue: onViewDue),
            ],
          ),
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.collection, required this.onChangeIcon});

  final CollectionListItem collection;
  final VoidCallback? onChangeIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = collection;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Tooltip(
          message: "Changer l'icône",
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('collection-icon'),
              onTap: onChangeIcon,
              borderRadius: AppTheme.radiusMd,
              child: Ink(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(c.color).withValues(alpha: 0.15),
                  borderRadius: AppTheme.radiusMd,
                ),
                child: Center(
                  child: Text(c.icon, style: const TextStyle(fontSize: 28)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      c.name,
                      style: theme.textTheme.displaySmall,
                      textScaler: MediaQuery.textScalerOf(
                        context,
                      ).clamp(maxScaleFactor: 1.4),
                    ),
                  ),
                  if (c.isDisabled) ...[
                    const SizedBox(width: AppSpacing.md),
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.sm),
                      child: DisabledBadge(label: 'Désactivée'),
                    ),
                  ],
                ],
              ),
              if (c.description.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  c.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StudyButton extends StatelessWidget {
  const _StudyButton({required this.onPressed, this.expanded = false});

  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = expanded
            ? (constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : AppTheme.contentMaxWidth)
            : 160.0;
        return SizedBox(
          width: width,
          height: 56,
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(AppIcons.play, size: 20),
            label: const Text('Étudier'),
          ),
        );
      },
    );
  }
}

class _CollectionProgress extends StatelessWidget {
  const _CollectionProgress({
    required this.collection,
    required this.onViewDue,
  });

  final CollectionListItem collection;
  final VoidCallback? onViewDue;

  @override
  Widget build(BuildContext context) {
    final c = collection;
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalStats =
            constraints.maxWidth >= 480 && !largeText(context);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Progression',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${(c.progress * 100).round()} %',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFeatures: AppTheme.tabularFigures,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${c.cardsDone} carte${c.cardsDone == 1 ? '' : 's'} étudiée${c.cardsDone == 1 ? '' : 's'} sur ${c.totalCards}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  label: 'Progression de la collection',
                  value: '${(c.progress * 100).round()} pour cent',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: c.progress,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceHigh,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (horizontalStats)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ProgressValue(
                          value: c.totalCards,
                          label: 'Cartes',
                        ),
                      ),
                      Expanded(
                        child: _ProgressValue(
                          value: c.cardsDone,
                          label: 'Étudiées',
                        ),
                      ),
                      Expanded(
                        child: _ProgressValue(
                          value: c.dueCards,
                          label: 'À étudier / réviser',
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _ProgressValue(
                        value: c.totalCards,
                        label: 'Cartes',
                        horizontal: true,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ProgressValue(
                        value: c.cardsDone,
                        label: 'Étudiées',
                        horizontal: true,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ProgressValue(
                        value: c.dueCards,
                        label: 'À étudier / réviser',
                        horizontal: true,
                      ),
                    ],
                  ),
                if (onViewDue != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onViewDue,
                      icon: const Icon(AppIcons.calendarDays, size: 18),
                      label: const Text('Voir les échéances'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProgressValue extends StatelessWidget {
  const _ProgressValue({
    required this.value,
    required this.label,
    this.horizontal = false,
  });

  final int value;
  final String label;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueText = Text(
      '$value',
      style: theme.textTheme.titleMedium?.copyWith(
        fontFeatures: AppTheme.tabularFigures,
      ),
    );
    final labelText = Text(
      label,
      textAlign: horizontal ? TextAlign.start : TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    if (horizontal) {
      return Row(
        children: [
          valueText,
          const SizedBox(width: AppSpacing.md),
          Expanded(child: labelText),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        valueText,
        const SizedBox(height: AppSpacing.xs),
        labelText,
      ],
    );
  }
}

class _DecksHeader extends StatelessWidget {
  const _DecksHeader({
    required this.deckCount,
    required this.field,
    required this.direction,
    required this.onSort,
  });

  final int? deckCount;
  final _DeckSortField field;
  final _SortDirection direction;
  final void Function(_DeckSortField, _SortDirection) onSort;

  PopupMenuItem<(_DeckSortField, _SortDirection)> _item(
    BuildContext context,
    _DeckSortField f,
    _SortDirection d,
    String label,
    IconData icon,
  ) {
    final selected = field == f && direction == d;
    return PopupMenuItem(
      value: (f, d),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label)),
          if (selected) ...[
            const SizedBox(width: AppSpacing.md),
            Icon(
              AppIcons.check,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = deckCount;
    return Row(
      children: [
        const Expanded(child: SectionLabel('Decks')),
        if (count != null)
          Text(
            count == 1 ? '1 deck' : '$count decks',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(width: AppSpacing.sm),
        PopupMenuButton<(_DeckSortField, _SortDirection)>(
          tooltip: 'Trier les decks',
          icon: const Icon(AppIcons.arrowUpDown),
          onSelected: (sort) => onSort(sort.$1, sort.$2),
          itemBuilder: (_) => [
            _item(
              context,
              _DeckSortField.importOrder,
              _SortDirection.ascending,
              'Importation croissant',
              AppIcons.arrowDown,
            ),
            _item(
              context,
              _DeckSortField.importOrder,
              _SortDirection.descending,
              'Importation décroissant',
              AppIcons.arrowUp,
            ),
            _item(
              context,
              _DeckSortField.name,
              _SortDirection.ascending,
              'Alphabet croissant',
              AppIcons.arrowDownAZ,
            ),
            _item(
              context,
              _DeckSortField.name,
              _SortDirection.descending,
              'Alphabet décroissant',
              AppIcons.arrowDownAZ,
            ),
          ],
        ),
      ],
    );
  }
}

class _ImportButton extends StatelessWidget {
  const _ImportButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => context.go('/import'),
      icon: const Icon(AppIcons.fileUp),
      label: const Text('Importer un CSV'),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement',
      // Défilable sans interaction: évite tout débordement sur petit écran.
      child: const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BackBar(),
            Row(
              children: [
                SkeletonBox(width: 56, height: 56, radius: AppTheme.radiusMd),
                SizedBox(width: AppSpacing.lg),
                SkeletonBox(height: 36, width: 240),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            SkeletonBox(height: 180, radius: AppTheme.radiusMd),
            SizedBox(height: AppSpacing.xl),
            _DeckSkeletons(),
          ],
        ),
      ),
    );
  }
}

class _DeckSkeletons extends StatelessWidget {
  const _DeckSkeletons();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = adaptiveColumns(context, constraints.maxWidth);
        final placeholders = List<Widget>.generate(
          4,
          (_) => const SkeletonBox(height: 112, radius: AppTheme.radiusMd),
        );
        return Column(
          children: [
            for (var i = 0; i < placeholders.length; i += columns)
              cardRow(placeholders.skip(i).take(columns).toList(), columns),
          ],
        );
      },
    );
  }
}

class DeckCard extends StatelessWidget {
  const DeckCard({
    super.key,
    required this.deck,
    required this.onTap,
    this.onDelete,
    this.onViewCards,
    this.onToggleDisabled,
  });

  final DeckListItem deck;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onViewCards;
  final VoidCallback? onToggleDisabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasOptions =
        onDelete != null || onViewCards != null || onToggleDisabled != null;
    final isUnavailable = deck.isDisabled || onTap == null;
    return Pressable(
      enabled: !isUnavailable,
      child: Opacity(
        opacity: isUnavailable ? 0.7 : 1,
        child: Card(
          child: InkWell(
            onTap: isUnavailable ? null : onTap,
            borderRadius: AppTheme.radiusMd,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: AppTheme.radiusSm,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(AppIcons.layers, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (deck.isDisabled) ...[
                          const DisabledBadge(label: 'Désactivé'),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        Text(deck.name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${deck.totalCards} cartes · ${(deck.progress * 100).round()} % étudiées',
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ProgressPill(
                          value: deck.progress,
                          semanticsLabel: 'Progression de ${deck.name}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (hasOptions)
                    PopupMenuButton<_DeckAction>(
                      tooltip: 'Options du deck',
                      icon: const Icon(AppIcons.ellipsis),
                      onSelected: (action) {
                        switch (action) {
                          case _DeckAction.viewCards:
                            onViewCards?.call();
                          case _DeckAction.toggleDisabled:
                            onToggleDisabled?.call();
                          case _DeckAction.delete:
                            onDelete?.call();
                        }
                      },
                      itemBuilder: (_) => [
                        if (onViewCards != null)
                          const PopupMenuItem(
                            value: _DeckAction.viewCards,
                            child: _MenuRow(
                              icon: AppIcons.list,
                              label: 'Voir les cartes',
                            ),
                          ),
                        if (onToggleDisabled != null)
                          PopupMenuItem(
                            value: _DeckAction.toggleDisabled,
                            child: _MenuRow(
                              icon: deck.isDisabled
                                  ? AppIcons.eye
                                  : AppIcons.eyeOff,
                              label: deck.isDisabled
                                  ? 'Réactiver le deck'
                                  : 'Désactiver le deck',
                            ),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: _DeckAction.delete,
                            child: _MenuRow(
                              icon: AppIcons.trash2,
                              label: 'Supprimer le deck',
                              destructive: true,
                            ),
                          ),
                      ],
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Icon(
                        AppIcons.chevronRight,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _DeckAction { viewCards, delete, toggleDisabled }
