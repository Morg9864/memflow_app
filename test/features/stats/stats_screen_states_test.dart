import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/features/stats/stats_screen.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:memflow/app/providers.dart';
import 'package:memflow/widgets/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _activityEmpty =
    'Pas encore d’activité. Termine une session pour voir ta progression ici.';
const _trendEmpty =
    'Pas encore de données de réussite. Elles apparaîtront après tes '
    'premières révisions.';
const _longText =
    'Parmi les mécanismes suivants, lequel explique le mieux pourquoi la '
    'réplication de l’ADN est dite semi-conservative chez les eucaryotes '
    'lors de la phase S du cycle cellulaire et de la division mitotique ?';

List<HeatmapCell> _days(List<int> counts) => [
  for (var i = 0; i < counts.length; i++)
    HeatmapCell(label: '${i + 1}/9', count: counts[i], isActive: counts[i] > 0),
];

// 42 révisions sur 6 jours, 8 aujourd'hui.
final _activeDays = _days([0, 0, 5, 0, 6, 0, 7, 0, 0, 8, 0, 8, 0, 8]);

final _full = StatisticsOverview(
  streakDays: 12,
  totalReviews: 1840,
  successRate: .78,
  studyDays: 6,
  heatmap: _activeDays,
  levelProgress: const [
    LevelProgress(level: 1, count: 142, progress: .5),
    LevelProgress(level: 2, count: 1, progress: .2),
  ],
  successTrend: const [
    StatisticsTrendPoint(label: '1/9', reviewCount: 30, successRate: .6),
    StatisticsTrendPoint(label: '2/9', reviewCount: 0, successRate: 0),
    StatisticsTrendPoint(label: '3/9', reviewCount: 20, successRate: .55),
    StatisticsTrendPoint(label: '4/9', reviewCount: 60, successRate: .87),
    StatisticsTrendPoint(label: '5/9', reviewCount: 0, successRate: 0),
  ],
  collectionProgress: const [
    CollectionStatistics(name: _longText, reviewCount: 600, successRate: .7),
    CollectionStatistics(name: 'React', reviewCount: 340, successRate: .64),
  ],
  modeProgress: const [
    ModeStatistics(
      mode: TestMode.multipleChoice,
      reviewCount: 800,
      successRate: .82,
    ),
  ],
  difficultCards: const [
    DifficultCardStatistics(
      question: _longText,
      errorCount: 9,
      reviewCount: 12,
      successRate: .25,
    ),
    DifficultCardStatistics(
      question: 'Que signifie « idempotent » ?',
      errorCount: 1,
      reviewCount: 10,
      successRate: .9,
    ),
  ],
);

final _allZero = StatisticsOverview(
  streakDays: 0,
  totalReviews: 0,
  successRate: 0,
  studyDays: 0,
  heatmap: _days(List.filled(14, 0)),
  levelProgress: const [],
  successTrend: const [
    StatisticsTrendPoint(label: '1/9', reviewCount: 0, successRate: 0),
    StatisticsTrendPoint(label: '2/9', reviewCount: 0, successRate: 0),
  ],
  collectionProgress: const [],
  modeProgress: const [],
  difficultCards: const [],
);

const _emptyLists = StatisticsOverview(
  streakDays: 0,
  totalReviews: 0,
  successRate: 0,
  studyDays: 0,
  heatmap: [],
  levelProgress: [],
  successTrend: [],
  collectionProgress: [],
  modeProgress: [],
  difficultCards: [],
);

Future<void> _pump(
  WidgetTester tester, {
  StatisticsOverview? data,
  Stream<StatisticsOverview>? stream,
  Size size = const Size(360, 800),
  double scale = 1,
  List<Override> extra = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/stats',
    routes: [
      GoRoute(path: '/stats', builder: (_, _) => const StatisticsScreen()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        statisticsOverviewProvider.overrideWith(
          (ref) => stream ?? Stream.value(data!),
        ),
        ...extra,
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Iterable<InlineSpan> _spans(InlineSpan root) {
  final out = <InlineSpan>[];
  root.visitChildren((s) {
    out.add(s);
    return true;
  });
  return [root, ...out];
}

void main() {
  const sizes = {
    '320x568': (Size(320, 568), 1.0),
    '360x800': (Size(360, 800), 1.0),
    '360x800 @2.0': (Size(360, 800), 2.0),
  };
  final datasets = {
    'données complètes': _full,
    'tout à zéro': _allZero,
    'listes vides': _emptyLists,
  };

  group('aucune exception', () {
    for (final s in sizes.entries) {
      for (final d in datasets.entries) {
        testWidgets('${d.key} à ${s.key}', (tester) async {
          await _pump(
            tester,
            data: d.value,
            size: s.value.$1,
            scale: s.value.$2,
          );
          expect(find.text('Statistiques'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('messages vides', () {
    testWidgets('absents avec des données', (tester) async {
      await _pump(tester, data: _full);
      expect(find.text(_activityEmpty), findsNothing);
      expect(find.text(_trendEmpty), findsNothing);
      expect(
        find.text('Les jours sans révision restent vides.'),
        findsOneWidget,
      );
    });

    testWidgets('présents sans activité ni réussite', (tester) async {
      for (final d in [_allZero, _emptyLists]) {
        await _pump(tester, data: d, size: const Size(360, 4000));
        expect(find.text(_activityEmpty), findsOneWidget);
        expect(find.text(_trendEmpty), findsOneWidget);
        // KPI: vrais zéros.
        expect(find.text('0 %'), findsOneWidget);
        // Sections sans donnée: masquées.
        expect(find.text('PROGRESSION PAR NIVEAU'), findsNothing);
        expect(find.text('PROGRESSION PAR COLLECTION'), findsNothing);
        expect(find.text('RÉUSSITE PAR MODE'), findsNothing);
        expect(find.text('CARTES LES PLUS DIFFICILES'), findsNothing);
      }
    });

    testWidgets(
      'message d’activité seul quand seule la tendance a des données',
      (tester) async {
        await _pump(
          tester,
          data: StatisticsOverview(
            streakDays: 0,
            totalReviews: 3,
            successRate: .5,
            studyDays: 1,
            heatmap: _days(List.filled(14, 0)),
            levelProgress: const [],
            successTrend: const [
              StatisticsTrendPoint(
                label: '1/9',
                reviewCount: 3,
                successRate: .5,
              ),
            ],
            collectionProgress: const [],
            modeProgress: const [],
            difficultCards: const [],
          ),
        );
        expect(find.text(_activityEmpty), findsOneWidget);
        expect(find.text(_trendEmpty), findsNothing);
      },
    );
  });

  group('graphiques', () {
    testWidgets('aucune barre pour les points sans révision', (tester) async {
      await _pump(
        tester,
        data: StatisticsOverview(
          streakDays: 0,
          totalReviews: 1,
          successRate: 1,
          studyDays: 0,
          heatmap: const [],
          levelProgress: const [],
          successTrend: _full.successTrend, // 5 points, 3 avec données
          collectionProgress: const [],
          modeProgress: const [],
          difficultCards: const [],
        ),
      );
      // Activité vide (pas de barres), seules les barres de tendance existent.
      expect(find.byType(FractionallySizedBox), findsNWidgets(3));
    });

    testWidgets('barres d’activité: une par jour actif', (tester) async {
      await _pump(
        tester,
        data: StatisticsOverview(
          streakDays: 0,
          totalReviews: 1,
          successRate: 1,
          studyDays: 6,
          heatmap: _activeDays,
          levelProgress: const [],
          successTrend: const [],
          collectionProgress: const [],
          modeProgress: const [],
          difficultCards: const [],
        ),
      );
      expect(find.byType(FractionallySizedBox), findsNWidgets(6));
      expect(find.text('0 %'), findsNothing);
    });

    testWidgets('sémantique calculée sur les données', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, data: _full);
      const activity =
          'Activité sur 14 jours : 42 révisions sur 6 jours, aujourd’hui 8';
      const trend =
          'Évolution de la réussite : réussite la plus récente 87 % (4/9)';
      expect(activitySemantics(_activeDays), activity);
      expect(trendSemantics(_full.successTrend), trend);
      expect(trendSemantics(_allZero.successTrend), isNull);
      expect(find.bySemanticsLabel(activity), findsOneWidget);
      expect(find.bySemanticsLabel(trend), findsOneWidget);
      handle.dispose();
    });
  });

  testWidgets('niveaux: nombre de cartes et titre', (tester) async {
    await _pump(tester, data: _full, size: const Size(360, 4000));
    expect(find.text('PROGRESSION PAR NIVEAU'), findsOneWidget);
    expect(find.text('Niv. 1, Basique'), findsOneWidget);
    expect(find.text('142 cartes'), findsOneWidget);
    expect(find.text('1 carte'), findsOneWidget);
    expect(find.text('Fondations et reconnaissance'), findsOneWidget);
  });

  testWidgets('cartes difficiles: détail libellé', (tester) async {
    await _pump(tester, data: _full, size: const Size(360, 4000));
    expect(find.text('9 erreurs · 12 vues'), findsOneWidget);
    expect(find.text('Réussite 25 %'), findsOneWidget);
    expect(find.text('1 erreur · 10 vues'), findsOneWidget);
  });

  group('chargement et erreur', () {
    testWidgets('squelettes pendant le chargement', (tester) async {
      final controller = StreamController<StatisticsOverview>();
      addTearDown(controller.close);
      await _pump(tester, stream: controller.stream);
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('erreur sans texte d’exception, retry relance le provider', (
      tester,
    ) async {
      var builds = 0;
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(
        initialLocation: '/stats',
        routes: [
          GoRoute(path: '/stats', builder: (_, _) => const StatisticsScreen()),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            statisticsOverviewProvider.overrideWith((ref) {
              builds++;
              return Stream<StatisticsOverview>.error(
                Exception('boom-secret-123'),
              );
            }),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AppErrorState), findsOneWidget);
      expect(find.textContaining('boom-secret'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      final before = builds;
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      expect(builds, greaterThan(before));
    });
  });

  testWidgets('textes ≥ 12 et jamais orange', (tester) async {
    for (final d in [_full, _allZero]) {
      await _pump(tester, data: d, size: const Size(360, 4000));
      var texts = 0;
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        for (final span in _spans(rich.text)) {
          if (span is! TextSpan || span.text == null || span.text!.isEmpty) {
            continue;
          }
          final style = span.style;
          if (style?.fontFamily == 'MaterialIcons') continue; // icônes
          texts++;
          final size = style?.fontSize;
          expect(size, isNotNull, reason: span.text);
          expect(size, greaterThanOrEqualTo(12), reason: span.text);
          expect(style?.color, isNot(AppColors.primary), reason: span.text);
        }
      }
      expect(texts, greaterThan(5));
    }
  });
}
