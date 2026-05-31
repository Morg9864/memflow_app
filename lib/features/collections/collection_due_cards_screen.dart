import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/ui.dart';

final _collectionDueCardsProvider =
    StreamProvider.family<List<FlashcardDueItem>, String>((ref, collectionId) {
      return ref
          .watch(appRepositoryProvider)
          .watchDueCardsForCollection(collectionId);
    });

class CollectionDueCardsScreen extends ConsumerStatefulWidget {
  const CollectionDueCardsScreen({
    super.key,
    required this.collectionId,
    required this.collectionName,
  });

  final String collectionId;
  final String collectionName;

  @override
  ConsumerState<CollectionDueCardsScreen> createState() =>
      _CollectionDueCardsScreenState();
}

class _CollectionDueCardsScreenState
    extends ConsumerState<CollectionDueCardsScreen> {
  String? _busyCardId;

  Future<void> _setDueAt(FlashcardDueItem card, DateTime dueAt) async {
    setState(() => _busyCardId = card.id);
    try {
      await ref
          .read(appRepositoryProvider)
          .updateFlashcardDueAt(cardId: card.id, dueAt: dueAt);
      if (!mounted) return;
      final label = dueAt.isAfter(DateTime.now())
          ? DateFormat('dd/MM/yyyy HH:mm').format(dueAt.toLocal())
          : 'now';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Prochaine révision: $label')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de modifier la date: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyCardId = null);
      }
    }
  }

  Future<void> _editDueAt(FlashcardDueItem card) async {
    final localDueAt = card.dueAt.toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: localDueAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(localDueAt),
    );
    if (time == null || !mounted) return;

    final nextDueAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    await _setDueAt(card, nextDueAt);
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(
      _collectionDueCardsProvider(widget.collectionId),
    );
    final theme = Theme.of(context);

    return AppScaffold(
      child: Column(
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
            ],
          ),
          const SizedBox(height: 8),
          Text('Échéances', style: theme.textTheme.displaySmall),
          const SizedBox(height: 4),
          Text(
            widget.collectionName,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          cardsAsync.when(
            data: (cards) => Text(
              '${cards.length} carte${cards.length == 1 ? '' : 's'}',
              style: theme.textTheme.bodyMedium,
            ),
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: cardsAsync.when(
              data: (cards) {
                if (cards.isEmpty) {
                  return const EmptyState(
                    title: 'Aucune carte',
                    message: 'Cette collection ne contient aucune carte.',
                  );
                }

                return ListView.separated(
                  itemCount: cards.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return _DueCardTile(
                      card: card,
                      busy: _busyCardId == card.id,
                      onEdit: () => _editDueAt(card),
                      onSetNow: () => _setDueAt(card, DateTime.now()),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text(error.toString()),
            ),
          ),
        ],
      ),
    );
  }
}

class _DueCardTile extends StatelessWidget {
  const _DueCardTile({
    required this.card,
    required this.busy,
    required this.onEdit,
    required this.onSetNow,
  });

  final FlashcardDueItem card;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onSetNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDueNow = card.isDueNow;
    final dueLabel = isDueNow
        ? 'now'
        : DateFormat('dd/MM/yyyy HH:mm').format(card.dueAt.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.question,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(card.deckName, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDueNow
                        ? theme.colorScheme.primary.withValues(alpha: 0.14)
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.45,
                          ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Prochaine révision',
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dueLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDueNow ? theme.colorScheme.primary : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else
                  PopupMenuButton<_DueCardAction>(
                    tooltip: 'Modifier la date',
                    onSelected: (action) {
                      switch (action) {
                        case _DueCardAction.edit:
                          onEdit();
                        case _DueCardAction.now:
                          onSetNow();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _DueCardAction.edit,
                        child: Row(
                          children: [
                            Icon(Icons.edit_calendar_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Modifier la date'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _DueCardAction.now,
                        child: Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Mettre à maintenant'),
                          ],
                        ),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.more_horiz_rounded),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _DueCardAction { edit, now }
