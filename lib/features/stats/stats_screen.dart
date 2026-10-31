import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../theme/app_theme.dart';
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

const _windowDays = 14;
const _activityEmpty =
    'Pas encore d’activité. Termine une session pour voir ta progression ici.';

String _pct(double value) => '${(value * 100).round()} %';

String _plural(int n, String one, String many) => '$n ${n > 1 ? many : one}';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statisticsOverviewProvider);

    return AppScaffold(
      child: stats.when(
        data: (data) => SyncRefreshIndicator(
          child: ListView(
            children: [
              const _Header(),
              const SizedBox(height: AppSpacing.xl),
              _KpiRow(data: data),
              const SizedBox(height: AppSpacing.xl),
              _ActivityCard(data: data),
              const SizedBox(height: AppSpacing.xl),
              _TrendSection(points: data.successTrend),
              if (data.levelProgress.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('Progression par niveau'),
                const SizedBox(height: AppSpacing.md),
                Column(
                  spacing: AppSpacing.md,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in data.levelProgress)
                      _LevelProgressCard(item: item),
                  ],
                ),
              ],
              if (data.collectionProgress.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('Progression par collection'),
                const SizedBox(height: AppSpacing.md),
                _ResponsiveGrid(
                  children: [
                    for (final item in data.collectionProgress)
                      _MetricRow(
                        title: item.name,
                        detail:
                            '${item.reviewCount} cartes · ${_pct(item.successRate)}',
                        value: item.successRate,
                      ),
                  ],
                ),
              ],
              if (data.modeProgress.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('Réussite par mode'),
                const SizedBox(height: AppSpacing.md),
                _ResponsiveGrid(
                  children: [
                    for (final item in data.modeProgress)
                      _MetricRow(
                        title: item.mode.label,
                        detail:
                            '${item.reviewCount} cartes · ${_pct(item.successRate)}',
                        value: item.successRate,
                      ),
                  ],
                ),
              ],
              if (data.difficultCards.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('Cartes les plus difficiles'),
                const SizedBox(height: AppSpacing.md),
                Column(
                  spacing: AppSpacing.md,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in data.difficultCards)
                      _DifficultCard(item: item),
                  ],
                ),
              ],
            ],
          ),
        ),
        loading: () => const _StatsSkeleton(),
        error: (error, stackTrace) => AppErrorState(
          title: 'Statistiques indisponibles',
          message: 'Impossible de charger tes statistiques. Réessaie.',
          onRetry: () => ref.invalidate(statisticsOverviewProvider),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // FittedBox: un titre d'un seul mot ne peut pas passer à la ligne.
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Semantics(
                header: true,
                child: Text(
                  'Statistiques',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
            ),
          ),
        ),
        const SyncNowButton(),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.data});

  final StatisticsOverview data;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        value: '${data.streakDays}',
        label: 'série',
        icon: Icons.local_fire_department_rounded,
      ),
      (
        value: '${data.totalReviews}',
        label: 'cartes vues',
        icon: Icons.menu_book_rounded,
      ),
      (
        value: _pct(data.successRate),
        label: 'réussite',
        icon: Icons.show_chart_rounded,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            MediaQuery.textScalerOf(context).scale(12) > 14.4 ||
            constraints.maxWidth < 260;
        final cards = [
          for (final i in items)
            StatCard(
              compact: true,
              horizontal: stacked,
              value: i.value,
              label: i.label,
              icon: i.icon,
            ),
        ];
        if (stacked) {
          return Column(
            spacing: AppSpacing.sm,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          );
        }
        return IntrinsicHeight(
          child: Row(
            spacing: AppSpacing.sm,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final c in cards) Expanded(child: c)],
          ),
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.data});

  final StatisticsOverview data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = data.heatmap;
    final days = all.length > _windowDays
        ? all.sublist(all.length - _windowDays)
        : all;
    final hasActivity = days.any((d) => d.count > 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: AppSpacing.md,
              runSpacing: 2,
              children: [
                Text('Activité', style: theme.textTheme.titleLarge),
                Text(
                  _plural(data.studyDays, 'jour d’étude', 'jours d’étude'),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('14 derniers jours', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            if (hasActivity)
              _ActivityChart(days: days)
            else
              Text(_activityEmpty, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

const _monthNames = [
  '',
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// Libellé d'activité pour le lecteur d'écran, calculé sur les données réelles.
String activitySemantics(List<HeatmapCell> days) {
  final total = days.fold(0, (sum, d) => sum + d.count);
  final active = days.where((d) => d.count > 0).length;
  final today = days.isEmpty ? 0 : days.last.count;
  return 'Activité sur ${days.length} jours : '
      '${_plural(total, 'révision', 'révisions')} '
      'sur ${_plural(active, 'jour', 'jours')}, aujourd’hui $today';
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.days});

  /// Non vide, avec au moins un jour actif (garanti par l'appelant).
  final List<HeatmapCell> days;

  static const _height = 120.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    final maxCount = days.fold(0, (m, d) => d.count > m ? d.count : m);
    final last = days.length - 1;

    // Étiquette tous les 3 jours en partant d'aujourd'hui; le mois s'ajoute à
    // la première étiquette et à chaque changement de mois.
    final labels = <int, String>{};
    int? prevMonth;
    for (var i = last % 3; i <= last; i += 3) {
      final parts = days[i].label.split('/');
      final month = parts.length > 1 ? int.tryParse(parts[1]) : null;
      final showMonth =
          month != null && month >= 1 && month <= 12 && month != prevMonth;
      labels[i] = showMonth
          ? '${parts.first} ${_monthNames[month]}'
          : parts.first;
      prevMonth = month ?? prevMonth;
    }

    return Semantics(
      container: true,
      label: activitySemantics(days),
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: _height,
              child: Row(
                children: [
                  for (final day in days)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: day.count > 0
                              ? FractionallySizedBox(
                                  heightFactor: (day.count / maxCount).clamp(
                                    0.04,
                                    1.0,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: primary,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                )
                              : SizedBox(
                                  width: 6,
                                  height: 2,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: muted.withValues(alpha: 0.35),
                                      borderRadius: AppTheme.radiusPill,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(height: 1, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: labels.containsKey(i)
                        ? Center(
                            child: OverflowBox(
                              maxWidth: 72,
                              fit: OverflowBoxFit.deferToChild,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    labels[i]!,
                                    softWrap: false,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: i == last
                                          ? FontWeight.w700
                                          : null,
                                      color: i == last
                                          ? theme.colorScheme.onSurface
                                          : null,
                                    ),
                                  ),
                                  if (i == last)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Libellé de tendance pour le lecteur d'écran. `null` sans donnée.
String? trendSemantics(List<StatisticsTrendPoint> points) {
  final latest = points.where((p) => p.reviewCount > 0).lastOrNull;
  if (latest == null) return null;
  return 'Évolution de la réussite : réussite la plus récente '
      '${_pct(latest.successRate)} (${latest.label})';
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({required this.points});

  final List<StatisticsTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = points.where((p) => p.reviewCount > 0).lastOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Évolution de la réussite'),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: latest == null
                ? Text(
                    'Pas encore de données de réussite. Elles apparaîtront '
                    'après tes premières révisions.',
                    style: theme.textTheme.bodyMedium,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        points.length > 1
                            ? 'Du ${points.first.label} au ${points.last.label}'
                            : points.first.label,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        container: true,
                        label: trendSemantics(points),
                        child: ExcludeSemantics(
                          child: _TrendChart(points: points),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.sm,
                        children: [
                          Text(
                            _pct(latest.successRate),
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            'réussite la plus récente (${latest.label})',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Les jours sans révision restent vides.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<StatisticsTrendPoint> points;

  static const _height = 100.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = theme.colorScheme.outlineVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('100 %', style: theme.textTheme.labelSmall),
              Text('0 %', style: theme.textTheme.labelSmall),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SizedBox(
            height: _height,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 1, color: line),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 1, color: line),
                ),
                Row(
                  children: [
                    for (final p in points)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: p.reviewCount > 0
                                ? FractionallySizedBox(
                                    heightFactor: p.successRate.clamp(
                                      0.02,
                                      1.0,
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(4),
                                            ),
                                      ),
                                      child: const SizedBox.expand(),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 600) {
      return Column(
        spacing: AppSpacing.md,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(detail, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            ProgressPill(value: value, semanticsLabel: '$title, $detail'),
          ],
        ),
      ),
    );
  }
}

class _DifficultCard extends StatelessWidget {
  const _DifficultCard({required this.item});

  final DifficultCardStatistics item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
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
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                Text(
                  '${_plural(item.errorCount, 'erreur', 'erreurs')} · ${item.reviewCount} vues',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  'Réussite ${_pct(item.successRate)}',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ],
        ),
      ),
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
    final title = 'Niv. ${item.level}, ${presentation.title}';
    final count = _plural(item.count, 'carte', 'cartes');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(icon: presentation.icon, size: 40),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      Text(
                        presentation.subtitle,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ProgressPill(
                    value: item.progress,
                    height: 8,
                    semanticsLabel: '$title, $count',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(count, style: theme.textTheme.labelLarge),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement des statistiques',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          Align(
            alignment: Alignment.centerLeft,
            child: SkeletonBox(width: 200, height: 36),
          ),
          SizedBox(height: AppSpacing.xl),
          Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(child: SkeletonBox(height: 84)),
              Expanded(child: SkeletonBox(height: 84)),
              Expanded(child: SkeletonBox(height: 84)),
            ],
          ),
          SizedBox(height: AppSpacing.xl),
          SkeletonBox(height: 220),
          SizedBox(height: AppSpacing.xl),
          SkeletonBox(height: 180),
        ],
      ),
    );
  }
}
