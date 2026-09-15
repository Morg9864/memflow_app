import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/ui.dart';

({String title, String subtitle, IconData icon}) _levelPresentation(int level) {
  return switch (level) {
    1 => (
      title: 'Basique',
      subtitle: 'Fondations et reconnaissance',
      icon: Icons.visibility_rounded,
    ),
    2 => (
      title: 'Intermédiaire',
      subtitle: 'Compréhension guidée',
      icon: Icons.tune_rounded,
    ),
    3 => (
      title: 'Actif',
      subtitle: 'Rappel actif et reformulation',
      icon: Icons.bolt_rounded,
    ),
    _ => (
      title: 'Avancé',
      subtitle: 'Maîtrise contextuelle',
      icon: Icons.psychology_alt_rounded,
    ),
  };
}

final statisticsOverviewProvider = StreamProvider<StatisticsOverview>((ref) {
  return ref.watch(appRepositoryProvider).watchStatisticsOverview();
});

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statisticsOverviewProvider);

    return AppScaffold(
      bottomNavigation: AppBottomNav(
        location: GoRouterState.of(context).uri.path,
      ),
      child: stats.when(
        data: (data) => ListView(
          children: [
            Row(
              children: [
                Text(
                  'Statistiques',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const Spacer(),
                const ThemeToggleButton(),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StatCard(
                    compact: true,
                    value: '${data.streakDays}',
                    label: 'série',
                    icon: Icons.local_fire_department_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    compact: true,
                    value: '${data.totalReviews}',
                    label: 'cartes vues',
                    icon: Icons.menu_book_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    compact: true,
                    value: '${(data.successRate * 100).round()}%',
                    label: 'réussite',
                    icon: Icons.show_chart_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Activité',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        Text('${data.studyDays} jours d’étude'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '14 derniers jours',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 22),
                    ActivityBarChart(days: data.heatmap),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _StatisticsDetails(data: data),
            const SizedBox(height: 20),
            const SectionLabel('Progression par niveau'),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in data.levelProgress)
                      SizedBox(
                        width: cardWidth,
                        child: _LevelProgressCard(item: item),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(error.toString()),
      ),
    );
  }
}

class _StatisticsDetails extends StatelessWidget {
  const _StatisticsDetails({required this.data});

  final StatisticsOverview data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Évolution de la réussite'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.successTrend.map((point) {
                final height = point.reviewCount == 0
                    ? 4.0
                    : 10 + point.successRate * 62;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 18,
                          child:
                              point.reviewCount > 0 &&
                                  point == data.successTrend.last
                              ? Text(
                                  '${(point.successRate * 100).round()}%',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.labelSmall,
                                )
                              : null,
                        ),
                        SizedBox(
                          height: 70,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: height,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          point.label.split('/').first,
                          style: Theme.of(context).textTheme.labelSmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (data.collectionProgress.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionLabel('Progression par collection'),
          const SizedBox(height: 12),
          _TwoColumnStatsGrid(
            children: [
              for (final item in data.collectionProgress)
                _MetricRow(
                  compact: true,
                  title: item.name,
                  detail:
                      '${item.reviewCount} cartes · ${_percent(item.successRate)}',
                  value: item.successRate,
                ),
            ],
          ),
        ],
        if (data.modeProgress.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionLabel('Réussite par mode'),
          const SizedBox(height: 12),
          _TwoColumnStatsGrid(
            children: [
              for (final item in data.modeProgress)
                _MetricRow(
                  compact: true,
                  title: item.mode.label,
                  detail:
                      '${item.reviewCount} cartes · ${_percent(item.successRate)}',
                  value: item.successRate,
                ),
            ],
          ),
        ],
        if (data.difficultCards.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionLabel('Cartes les plus difficiles'),
          const SizedBox(height: 12),
          _TwoColumnStatsGrid(
            children: [
              for (final item in data.difficultCards)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.question,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.errorCount} erreur${item.errorCount > 1 ? 's' : ''} · ${item.reviewCount} vues',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(_percent(item.successRate)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  static String _percent(double value) => '${(value * 100).round()}%';
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    this.compact = false,
    required this.title,
    required this.detail,
    required this.value,
  });

  final String title;
  final String detail;
  final double value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: compact ? 2 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SizedBox(height: compact ? 10 : 9),
              ProgressPill(value: value),
            ],
          ),
        ),
      ),
    );
  }
}

class _TwoColumnStatsGrid extends StatelessWidget {
  const _TwoColumnStatsGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        );
      },
    );
  }
}

class _LevelProgressCard extends StatelessWidget {
  const _LevelProgressCard({required this.item});

  final LevelProgress item;

  @override
  Widget build(BuildContext context) {
    final presentation = _levelPresentation(item.level);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(icon: presentation.icon, size: 36),
            const SizedBox(height: 12),
            Text(
              'Niv. ${item.level}, ${presentation.title}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 5),
            Text(
              presentation.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: ProgressPill(value: item.progress)),
                const SizedBox(width: 8),
                Text('${item.count}', style: theme.textTheme.titleMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
