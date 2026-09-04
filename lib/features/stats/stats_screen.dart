import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/ui.dart';

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
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 720 ? 3 : 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                StatCard(
                  value: '${data.streakDays}',
                  label: 'série',
                  icon: Icons.local_fire_department_rounded,
                ),
                StatCard(
                  value: '${data.totalReviews}',
                  label: 'cartes vues',
                  icon: Icons.menu_book_rounded,
                ),
                StatCard(
                  value: '${(data.successRate * 100).round()}%',
                  label: 'réussite',
                  icon: Icons.show_chart_rounded,
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
            ...data.levelProgress.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        IconTile(icon: item.icon),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Niv. ${item.level}, ${item.title}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.subtitle,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              ProgressPill(value: item.progress),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${item.count}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                    ? 8.0
                    : 12 + point.successRate * 64;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      children: [
                        Text(
                          point.reviewCount == 0
                              ? '—'
                              : '${(point.successRate * 100).round()}%',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          point.label,
                          style: Theme.of(context).textTheme.labelSmall,
                          overflow: TextOverflow.clip,
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
          ...data.collectionProgress.map(
            (item) => _MetricRow(
              title: item.name,
              detail:
                  '${item.reviewCount} cartes · ${_percent(item.successRate)}',
              value: item.successRate,
            ),
          ),
        ],
        if (data.modeProgress.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionLabel('Réussite par mode'),
          const SizedBox(height: 12),
          ...data.modeProgress.map(
            (item) => _MetricRow(
              title: item.mode.label,
              detail:
                  '${item.reviewCount} cartes · ${_percent(item.successRate)}',
              value: item.successRate,
            ),
          ),
        ],
        if (data.difficultCards.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionLabel('Cartes les plus difficiles'),
          const SizedBox(height: 12),
          ...data.difficultCards.map(
            (item) => Card(
              child: ListTile(
                title: Text(
                  item.question,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${item.errorCount} erreur${item.errorCount > 1 ? 's' : ''} · ${item.reviewCount} vues',
                ),
                trailing: Text(_percent(item.successRate)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _percent(double value) => '${(value * 100).round()}%';
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.title,
    required this.detail,
    required this.value,
  });

  final String title;
  final String detail;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 9),
              ProgressPill(value: value),
            ],
          ),
        ),
      ),
    );
  }
}
