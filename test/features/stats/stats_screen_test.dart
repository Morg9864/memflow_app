import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/features/stats/stats_screen.dart';
import 'package:memflow/theme/theme_controller.dart';
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
}

Future<SharedPreferences> _testPreferences() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}
