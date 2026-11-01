import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/features/stats/stats_screen.dart';
import 'package:memflow/app/providers.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('affiche les indicateurs détaillés des statistiques', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const overview = StatisticsOverview(
      streakDays: 2,
      totalReviews: 8,
      successRate: .75,
      studyDays: 3,
      heatmap: [],
      levelProgress: [],
      successTrend: [
        StatisticsTrendPoint(label: '1/1', reviewCount: 4, successRate: .75),
      ],
      collectionProgress: [
        CollectionStatistics(name: 'React', reviewCount: 4, successRate: .75),
      ],
      modeProgress: [
        ModeStatistics(
          mode: TestMode.multipleChoice,
          reviewCount: 4,
          successRate: .75,
        ),
      ],
      difficultCards: [
        DifficultCardStatistics(
          question: 'Quelle est la question difficile ?',
          errorCount: 2,
          reviewCount: 4,
          successRate: .5,
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: '/stats',
      routes: [
        GoRoute(path: '/stats', builder: (_, __) => const StatisticsScreen()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await _testPreferences()),
          statisticsOverviewProvider.overrideWith(
            (ref) => Stream.value(overview),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    expect(find.text('PROGRESSION PAR COLLECTION'), findsOneWidget);
    expect(find.text('React'), findsOneWidget);
    expect(find.text('RÉUSSITE PAR MODE'), findsOneWidget);
    expect(find.text('CARTES LES PLUS DIFFICILES'), findsOneWidget);
    expect(find.text('Quelle est la question difficile ?'), findsOneWidget);
  });

  group('layout selon la largeur utile', () {
    const overview = StatisticsOverview(
      streakDays: 2,
      totalReviews: 8,
      successRate: .75,
      studyDays: 3,
      heatmap: [HeatmapCell(label: '1/1', count: 3, isActive: true)],
      levelProgress: [
        LevelProgress(level: 1, count: 10, progress: .5),
        LevelProgress(level: 2, count: 5, progress: .3),
      ],
      successTrend: [
        StatisticsTrendPoint(label: '1/1', reviewCount: 4, successRate: .75),
      ],
      collectionProgress: [],
      modeProgress: [],
      difficultCards: [],
    );

    Future<void> pumpAt(WidgetTester tester, Size size, double scale) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await _testPreferences(),
            ),
            statisticsOverviewProvider.overrideWith(
              (ref) => Stream.value(overview),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const StatisticsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    double dx(WidgetTester tester, String text) =>
        tester.getTopLeft(find.text(text)).dx;

    testWidgets('grille de niveaux: 2 colonnes à 880x1408', (tester) async {
      await pumpAt(tester, const Size(880, 1408), 1);
      expect(dx(tester, 'Niv. 1, Basique'), lessThan(440));
      expect(dx(tester, 'Niv. 2, Intermédiaire'), greaterThan(440));
    });

    testWidgets('grille de niveaux: 1 colonne à 360x800', (tester) async {
      await pumpAt(tester, const Size(360, 2400), 1);
      expect(
        dx(tester, 'Niv. 2, Intermédiaire'),
        dx(tester, 'Niv. 1, Basique'),
      );
    });

    testWidgets('grille de niveaux: 1 colonne à 880x1408 en texte x2', (
      tester,
    ) async {
      await pumpAt(tester, const Size(880, 1408), 2);
      expect(
        dx(tester, 'Niv. 2, Intermédiaire'),
        dx(tester, 'Niv. 1, Basique'),
      );
    });

    testWidgets('activité et tendance côte à côte à 1408x880', (tester) async {
      await pumpAt(tester, const Size(1408, 880), 1);
      expect(
        tester.getTopLeft(find.text('Évolution de la réussite')).dy,
        tester.getTopLeft(find.text('Activité')).dy,
      );
    });

    testWidgets('activité et tendance empilées à 880x1408', (tester) async {
      await pumpAt(tester, const Size(880, 1408), 1);
      expect(
        tester.getTopLeft(find.text('ÉVOLUTION DE LA RÉUSSITE')).dy,
        greaterThan(tester.getBottomLeft(find.text('Activité')).dy),
      );
    });
  });
}

Future<SharedPreferences> _testPreferences() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}
