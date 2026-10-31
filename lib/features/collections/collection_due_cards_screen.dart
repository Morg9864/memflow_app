import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import 'collection_list_widgets.dart';
import 'paginated_list_controller.dart';

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
  static const _pageSize = 40;

  late final PaginatedListController<FlashcardDueItem> _controller;
  final ScrollController _scrollController = ScrollController();
  String? _busyCardId;

  @override
  void initState() {
    super.initState();
    final repository = ref.read(appRepositoryProvider);
    _controller = PaginatedListController<FlashcardDueItem>(
      pageSize: _pageSize,
      loadSlice: ({required offset, required limit}) {
        return repository.fetchDueCardsForCollectionPage(
          collectionId: widget.collectionId,
          offset: offset,
          limit: limit,
        );
      },
      refreshStream: repository.watchDueCardsForCollectionRevision(),
    )..addListener(_handleControllerChange);
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.start();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _controller
      ..removeListener(_handleControllerChange)
      ..dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter < 280) {
      _controller.loadMore();
    }
  }

  Future<void> _setDueAt(FlashcardDueItem card, DateTime dueAt) async {
    setState(() => _busyCardId = card.id);
    try {
      await ref
          .read(appRepositoryProvider)
          .updateFlashcardDueAt(cardId: card.id, dueAt: dueAt);
      if (!mounted) {
        return;
      }
      final label = dueAt.isAfter(DateTime.now())
          ? DateFormat('dd/MM/yyyy HH:mm').format(dueAt.toLocal())
          : 'now';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Prochaine révision: $label')));
      await _controller.refresh();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de modifier la date.')),
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
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(localDueAt),
    );
    if (time == null || !mounted) {
      return;
    }

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
    final state = _controller.state;

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListScreenHeader(
            title: 'Échéances',
            subtitle: widget.collectionName,
            backFallback: '/collection/${widget.collectionId}',
            count: state.isInitialLoading ? null : state.totalCount,
          ),
          Expanded(child: _buildBody(context, state)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PaginatedListState<FlashcardDueItem> state,
  ) {
    if (state.isInitialLoading && state.items.isEmpty) {
      return const ListSkeleton();
    }

    if (state.error != null && state.items.isEmpty) {
      return AppErrorState(
        message: 'Impossible de charger les échéances.',
        onRetry: () => _controller.refresh(),
      );
    }

    if (state.items.isEmpty) {
      return const EmptyState(
        title: 'Aucune carte',
        message: 'Cette collection ne contient aucune carte active.',
      );
    }

    return SyncRefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView.separated(
        controller: _scrollController,
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const PaginationFooter();
          }

          final card = state.items[index];
          return _DueCardTile(
            card: card,
            busy: _busyCardId == card.id,
            onEdit: () => _editDueAt(card),
            onSetNow: () => _setDueAt(card, DateTime.now()),
          );
        },
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.question,
                      style: theme.textTheme.titleMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(card.deckName, style: theme.textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isDueNow
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Prochaine révision : $dueLabel',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (busy)
              const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                ),
              )
            else
              PopupMenuButton<_DueCardAction>(
                tooltip: 'Modifier la date',
                icon: const Icon(Icons.more_horiz_rounded),
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
                        SizedBox(width: AppSpacing.md),
                        Expanded(child: Text('Choisir une date')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _DueCardAction.now,
                    child: Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 20),
                        SizedBox(width: AppSpacing.md),
                        Expanded(child: Text('Remettre à now')),
                      ],
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
