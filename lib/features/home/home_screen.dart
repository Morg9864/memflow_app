import 'package:memflow/theme/app_icons.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../domain/models/study_planning.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../planning/planning_screen.dart';

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
        // Pas de SliverLayoutBuilder pour la largeur : il se reconstruit à chaque
        // décalage de défilement, et toute la liste avec lui.
        child: LayoutBuilder(
          builder: (context, viewport) => CustomScrollView(
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
                      data: (data) => _Overview(stats: data),
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
                        prefixIcon: Icon(AppIcons.search),
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
                _CollectionsSliver(
                  items: items,
                  search: _search,
                  width: viewport.maxWidth,
                )
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
          icon: const Icon(AppIcons.chartNoAxesColumnIncreasing),
        ),
        const SizedBox(width: AppSpacing.sm),
        const SyncNowButton(),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.dueCards, this.planning});

  final int dueCards;
  final PlanningOverview? planning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = planning?.progress();
    final hasPlans = planning?.plans.isNotEmpty ?? true;
    final hasFollowUp = planning?.pendingFollowUps.isNotEmpty ?? false;
    final studyLocation = planning == null ? '/study' : plannedStudyLocation();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dueCards > 0) ...[
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
            ] else ...[
              Icon(
                hasPlans ? AppIcons.circleCheck : AppIcons.calendarDays,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                !hasPlans
                    ? 'Planifie tes révisions'
                    : (today?.isComplete ?? false)
                    ? 'Planning du jour terminé'
                    : 'Tout est à jour',
                style: theme.textTheme.titleLarge,
              ),
              if (!hasPlans || today?.total == 0 || today == null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  hasPlans
                      ? 'Aucune carte à réviser aujourd’hui.'
                      : 'Choisis les cours à travailler et les jours de révision.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
            if (today != null && today.total > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('${today.worked} sur ${today.total} cartes travaillées'),
              const SizedBox(height: AppSpacing.xs),
              ProgressPill(
                value: today.worked / today.total,
                semanticsLabel: 'Progression du planning',
              ),
            ],
            if (dueCards > 0) ...[
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                container: true,
                button: true,
                excludeSemantics: true,
                label: dueCards == 1
                    ? 'Commencer une session de 1 carte'
                    : 'Commencer une session de $dueCards cartes',
                onTap: () => context.push(studyLocation),
                child: Pressable(
                  child: FilledButton.icon(
                    key: const ValueKey('home-study-cta'),
                    onPressed: () => context.push(studyLocation),
                    icon: const Icon(AppIcons.play),
                    label: const Text('Étudier maintenant'),
                  ),
                ),
              ),
            ],
            if (planning != null) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => context.push(planningLocation()),
                    icon: const Icon(AppIcons.calendarDays),
                    label: Text(
                      !hasPlans
                          ? 'Créer un planning'
                          : hasFollowUp
                          ? 'Choisir la suite'
                          : 'Voir le planning',
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/study'),
                    child: const Text('Révision libre'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Le héros « cartes à revoir » et les deux statistiques. Sur tablette, le
/// héros passe à gauche des statistiques empilées (même hauteur totale); sinon,
/// ou avec un texte agrandi, tout s'empile comme sur téléphone.
class _Overview extends StatelessWidget {
  const _Overview({required this.stats});

  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final streak = StatCard(
      value: '${stats.streakDays} j',
      label: 'de série',
      iconContent: const Text(
        '🔥',
        style: TextStyle(fontSize: 20, color: AppColors.text),
      ),
    );
    final success = StatCard(
      value:
          stats.planning != null &&
              stats.planning!.progress().successRate == null
          ? '—'
          : '${(stats.successRate * 100).round()} %',
      label: 'de réussite',
      icon: AppIcons.circleCheck,
    );
    final hero = _HeroCard(dueCards: stats.dueCards, planning: stats.planning);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_heroBeside(context, constraints.maxWidth)) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: hero),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: streak),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(child: success),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero,
            const SizedBox(height: AppSpacing.md),
            // Au-delà d'un texte agrandi, deux colonnes ne tiennent plus: on
            // empile.
            if (largeText(context)) ...[
              streak,
              const SizedBox(height: AppSpacing.md),
              success,
            ] else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: streak),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: success),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// Largeur utile (rail et marges déduits), pas celle de la fenêtre.
bool _heroBeside(BuildContext context, double width) =>
    width >= AppBreakpoints.tablet && !largeText(context);

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
          icon: const Icon(AppIcons.fileUp),
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
    const box = SkeletonBox(height: 110, radius: AppTheme.radiusMd);
    return Semantics(
      label: 'Chargement',
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Même découpage que _Overview: pas de saut à la fin du chargement.
          if (_heroBeside(context, constraints.maxWidth)) {
            return const SizedBox(
              height: 232,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SkeletonBox(
                      height: double.infinity,
                      radius: AppTheme.radiusMd,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Expanded(child: box),
                        SizedBox(height: AppSpacing.md),
                        Expanded(child: box),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return const Column(
            children: [
              SkeletonBox(height: 190, radius: AppTheme.radiusMd),
              SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(child: box),
                  SizedBox(width: AppSpacing.md),
                  Expanded(child: box),
                ],
              ),
            ],
          );
        },
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
  const _CollectionsSliver({
    required this.items,
    required this.search,
    required this.width,
  });

  final List<CollectionListItem> items;
  final String search;

  /// Largeur réellement disponible (rail et marges déduits), pas la fenêtre.
  final double width;

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
                  icon: const Icon(AppIcons.fileUp),
                  label: const Text('Importer un fichier CSV'),
                ),
              )
            : EmptyState(
                icon: AppIcons.searchX,
                title: 'Aucun résultat',
                message: 'Aucune collection ne correspond à « $search ».',
              ),
      );
    }

    final columns = adaptiveColumns(context, width);
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
        return cardRow([
          for (final item in entry.items) _CollectionCard(collection: item),
        ], columns);
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
    final dueReview = c.srsEnabled ? c.nextReviewAt : null;
    final tablet = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;
    final summary = StringBuffer(c.name);
    if (c.sessionTotal > 0) {
      summary.write(
        ', ${c.sessionWorked} sur ${c.sessionTotal} cartes travaillées',
      );
    }
    if (c.dueCards > 0) summary.write(', ${c.dueCards} à revoir');
    if (c.isDisabled) summary.write(', désactivée');
    if (c.nextSessionAt case final next?) {
      summary.write(', prochaine séance ${formatRelativePlanningDate(next)}');
    } else if (dueReview case final next?) {
      summary.write(', prochaine révision ${formatRelativeSrsDate(next)}');
    } else if (c.sessionDate != null &&
        c.sessionDate!.isBefore(studyDay(DateTime.now()))) {
      summary.write(
        ', dernière séance ${formatRelativePlanningDate(c.sessionDate!)}',
      );
    }

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
                padding: EdgeInsets.all(tablet ? 20 : AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      key: ValueKey('collection-tile-${c.id}'),
                      width: tablet ? 52 : 44,
                      height: tablet ? 52 : 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Color(c.color).withValues(alpha: 0.15),
                        borderRadius: AppTheme.radiusSm,
                      ),
                      child: Text(c.icon, style: const TextStyle(fontSize: 22)),
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
                            c.sessionTotal > 0
                                ? '${c.sessionWorked} / ${c.sessionTotal} cartes travaillées'
                                : 'Aucune carte prévue aujourd’hui',
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
                          if (c.nextSessionAt case final next?) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Prochaine séance ${formatRelativePlanningDate(next)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ] else if (dueReview case final due?) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Prochaine révision ${formatRelativeSrsDate(due)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ] else if (c.sessionDate != null &&
                              c.sessionDate!.isBefore(
                                studyDay(DateTime.now()),
                              )) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Dernière séance ${formatRelativePlanningDate(c.sessionDate!)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          ProgressPill(
                            value: c.sessionProgress,
                            semanticsLabel: 'Progression de ${c.name}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
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
      ),
    );
  }
}
