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
      bottomNavigation: AppBottomNav(location: GoRouterState.of(context).uri.path),
      child: stats.when(
        data: (data) => ListView(
          children: [
            Row(
              children: [
                Text('Statistiques', style: Theme.of(context).textTheme.displaySmall),
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
                        Text('Activité', style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        Text('${data.studyDays} jours d’étude'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('4 dernières semaines', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 22),
                    HeatmapGrid(rows: data.heatmap),
                  ],
                ),
              ),
            ),
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
                              Text('Niv. ${item.level}, ${item.title}',
                                  style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 6),
                              Text(item.subtitle, style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 12),
                              ProgressPill(value: item.progress),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text('${item.count}', style: Theme.of(context).textTheme.titleLarge),
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
