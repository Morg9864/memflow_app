import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

final homeStatsProvider = StreamProvider<HomeStats>((ref) {
  return ref.watch(appRepositoryProvider).watchHomeStats();
});

final homeCollectionsProvider = StreamProvider.autoDispose
    .family<List<CollectionListItem>, String>((ref, search) {
      return ref.watch(appRepositoryProvider).watchCollections(search: search);
    });

const _searchDebounce = Duration(milliseconds: 250);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';

  // Résultats précédents, affichés pendant qu'une nouvelle recherche charge.
  List<CollectionListItem>? _shown;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (mounted) setState(() => _search = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(homeStatsProvider);
    final collections = ref.watch(homeCollectionsProvider(_search));
    final displayName = ref.watch(displayNameProvider);

    final fresh = collections.value;
    if (fresh != null) _shown = fresh;
    final items = fresh ?? _shown;

    return AppScaffold(
      child: SyncRefreshIndicator(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Header(),
                  const SizedBox(height: AppSpacing.xl),
                  SectionLabel(
                    displayName == null ? 'Bonjour' : 'Bonjour, $displayName',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  stats.when(
                    data: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeroCard(dueCards: data.dueCards),
                        const SizedBox(height: AppSpacing.md),
                        _StatsRow(stats: data),
                      ],
                    ),
                    loading: () => const _StatsSkeleton(),
                    error: (error, stackTrace) => AppErrorState(
                      onRetry: () => ref.invalidate(homeStatsProvider),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher une collection',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _CollectionsHeader(),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
            if (items != null)
              _CollectionsSliver(items: items, search: _search)
            else if (collections.hasError)
              SliverToBoxAdapter(
                child: AppErrorState(
                  onRetry: () =>
                      ref.invalidate(homeCollectionsProvider(_search)),
                ),
              )
            else
              const SliverToBoxAdapter(child: _CollectionsSkeleton()),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.headlineMedium;
    return Row(
      children: [
        Expanded(
          // FittedBox: le logo rétrécit plutôt que de faire déborder la ligne.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                style: style,
                children: [
                  TextSpan(
                    text: 'Mem',
                    style: style?.copyWith(color: theme.colorScheme.onSurface),
                  ),
                  TextSpan(
                    text: 'Flow',
                    style: style?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Voir les statistiques',
          onPressed: () => context.go('/stats'),
          icon: const Icon(Icons.insights_rounded),
        ),
        const SizedBox(width: AppSpacing.sm),
        const SyncNowButton(),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.dueCards});

  final int dueCards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upToDate = dueCards == 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: upToDate
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Tout est à jour', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Aucune carte à réviser aujourd’hui.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$dueCards',
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    dueCards == 1 ? 'carte à revoir' : 'cartes à revoir',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    container: true,
                    button: true,
                    excludeSemantics: true,
                    label: dueCards == 1
                        ? 'Commencer une session de 1 carte'
                        : 'Commencer une session de $dueCards cartes',
                    onTap: () => context.push('/study'),
                    child: Pressable(
                      child: FilledButton.icon(
                        key: const ValueKey('home-study-cta'),
                        onPressed: () => context.push('/study'),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Étudier maintenant'),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final streak = StatCard(
      value: '${stats.streakDays} j',
      label: 'de série',
      icon: Icons.local_fire_department_rounded,
    );
    final success = StatCard(
      value: '${(stats.successRate * 100).round()} %',
      label: 'de réussite',
      icon: Icons.task_alt_rounded,
    );
    // Au-delà d'un texte agrandi, deux colonnes ne tiennent plus: on empile.
    final stack = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.3;
    if (stack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          streak,
          const SizedBox(height: AppSpacing.md),
          success,
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: streak),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: success),
        ],
      ),
    );
  }
}

class _CollectionsHeader extends StatelessWidget {
  const _CollectionsHeader();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const SectionLabel('Collections'),
        TextButton.icon(
          onPressed: () => context.go('/import'),
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Importer CSV'),
        ),
      ],
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement',
      child: const Column(
        children: [
          SkeletonBox(height: 190, radius: AppTheme.radiusMd),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SkeletonBox(height: 110, radius: AppTheme.radiusMd),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: SkeletonBox(height: 110, radius: AppTheme.radiusMd),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectionsSkeleton extends StatelessWidget {
  const _CollectionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          SkeletonBox(height: 104, radius: AppTheme.radiusMd),
          SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// Une entrée de la liste: soit une ligne de cartes, soit l'intertitre
/// « Désactivé(s) ».
class _Entry {
  const _Entry.row(this.items) : disabledHeader = false;
  const _Entry.header() : items = const [], disabledHeader = true;

  final List<CollectionListItem> items;
  final bool disabledHeader;
}

class _CollectionsSliver extends StatelessWidget {
  const _CollectionsSliver({required this.items, required this.search});

  final List<CollectionListItem> items;
  final String search;

  static List<_Entry> _rows(List<CollectionListItem> list, int columns) => [
    for (var i = 0; i < list.length; i += columns)
      _Entry.row(list.sublist(i, (i + columns).clamp(0, list.length))),
  ];

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: search.isEmpty
            ? EmptyState(
                title: 'Aucune collection',
                message:
                    'Importe un fichier CSV pour créer ta première '
                    'collection.',
                action: FilledButton.icon(
                  onPressed: () => context.go('/import'),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Importer un fichier CSV'),
                ),
              )
            : EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Aucun résultat',
                message: 'Aucune collection ne correspond à « $search ».',
              ),
      );
    }

    final columns = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet
        ? 2
        : 1;
    final active = items.where((i) => !i.isDisabled).toList();
    final disabled = items.where((i) => i.isDisabled).toList();
    final entries = [
      ..._rows(active, columns),
      if (disabled.isNotEmpty) const _Entry.header(),
      ..._rows(disabled, columns),
    ];

    return SliverList.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry.disabledHeader) {
          return const Padding(
            padding: EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SectionLabel('Désactivé(s)'),
            ),
          );
        }
        final cards = [
          for (final item in entry.items) _CollectionCard(collection: item),
        ];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: columns == 1
              ? cards.first
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards.first),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: cards.length > 1
                            ? cards.last
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection});

  final CollectionListItem collection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = collection;
    final summary = StringBuffer(
      '${c.name}, ${c.cardsDone} sur ${c.totalCards} cartes faites',
    );
    if (c.dueCards > 0) summary.write(', ${c.dueCards} à revoir');
    if (c.isDisabled) summary.write(', désactivée');

    void open() => context.push('/collection/${c.id}');

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: summary.toString(),
      onTap: open,
      child: Pressable(
        child: Opacity(
          opacity: c.isDisabled ? 0.7 : 1,
          child: Card(
            child: InkWell(
              borderRadius: AppTheme.radiusMd,
              onTap: open,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      key: ValueKey('collection-tile-${c.id}'),
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Color(c.color).withValues(alpha: 0.15),
                        borderRadius: AppTheme.radiusSm,
                      ),
                      child: Text(
                        c.icon,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (c.isDisabled) ...[
                            const DisabledBadge(label: 'Désactivée'),
                            const SizedBox(height: AppSpacing.xs),
                          ],
                          Text(c.name, style: theme.textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${c.cardsDone} / ${c.totalCards} cartes faites',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (c.dueCards > 0 && !c.isDisabled) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    '${c.dueCards} à revoir',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          ProgressPill(
                            value: c.progress,
                            semanticsLabel: 'Progression de ${c.name}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
