import 'package:memflow/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/ui.dart';
import 'collection_list_widgets.dart';
import 'paginated_list_controller.dart';

class DeckCardsScreen extends ConsumerStatefulWidget {
  const DeckCardsScreen({
    super.key,
    required this.deckId,
    required this.deckName,
  });

  final String deckId;
  final String deckName;

  @override
  ConsumerState<DeckCardsScreen> createState() => _DeckCardsScreenState();
}

class _DeckCardsScreenState extends ConsumerState<DeckCardsScreen> {
  static const _pageSize = 40;

  late final PaginatedListController<FlashcardSummary> _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final repository = ref.read(appRepositoryProvider);
    _controller = PaginatedListController<FlashcardSummary>(
      pageSize: _pageSize,
      loadSlice: ({required offset, required limit}) {
        return repository.fetchFlashcardsForDeckPage(
          deckId: widget.deckId,
          offset: offset,
          limit: limit,
        );
      },
      refreshStream: repository.watchDeckCardsRevision(),
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

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListScreenHeader(
            title: widget.deckName,
            backFallback: '/',
            count: state.isInitialLoading ? null : state.totalCount,
          ),
          Expanded(child: _buildBody(context, state)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PaginatedListState<FlashcardSummary> state,
  ) {
    if (state.isInitialLoading && state.items.isEmpty) {
      return const ListSkeleton();
    }

    if (state.error != null && state.items.isEmpty) {
      return AppErrorState(
        message: 'Impossible de charger les cartes.',
        onRetry: () => _controller.refresh(),
      );
    }

    if (state.items.isEmpty) {
      return const EmptyState(
        title: 'Aucune carte',
        message: 'Ce deck ne contient aucune carte.',
      );
    }

    return SyncRefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView.separated(
        controller: _scrollController,
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const PaginationFooter();
          }

          final card = state.items[index];
          return _CardTile(
            card: card,
            onDelete: () => _confirmDeleteCard(context, ref, card),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteCard(
    BuildContext context,
    WidgetRef ref,
    FlashcardSummary card,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la carte ?'),
        content: Text(
          '"${card.question.length > 80 ? '${card.question.substring(0, 80)}…' : card.question}"',
        ),
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
    if (confirmed != true) {
      return;
    }
    await ref.read(appRepositoryProvider).deleteFlashcard(card.id);
    await _controller.refresh();
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.onDelete});

  final FlashcardSummary card;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tablet = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;
    return Card(
      child: Padding(
        // Lignes un peu plus hautes sur tablette: ce sont des listes à parcourir.
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          tablet ? AppSpacing.lg : AppSpacing.md,
          AppSpacing.sm,
          tablet ? AppSpacing.lg : AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.question,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    card.correctAnswer,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(AppIcons.trash2, color: theme.colorScheme.error),
              tooltip: 'Supprimer',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
