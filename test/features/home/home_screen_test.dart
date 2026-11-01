import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/app/providers.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/features/home/home_screen.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:memflow/widgets/ui.dart';

final _now = DateTime(2025, 1, 1);

CollectionListItem _col(
  String id,
  String name, {
  int due = 12,
  bool disabled = false,
}) => CollectionListItem(
  id: id,
  name: name,
  description: '',
  icon: '🧬',
  totalCards: 640,
  cardsDone: 210,
  dueCards: due,
  color: 0xFF4D79B5,
  createdAt: _now,
  updatedAt: _now,
  errorCount: 0,
  isDisabled: disabled,
);

HomeStats _stats({int due = 734}) => HomeStats(
  streakDays: 12,
  successRate: .82,
  dueCards: due,
  totalCardsSeen: 2400,
);

typedef _Collections = Stream<List<CollectionListItem>> Function(String search);

Stream<List<CollectionListItem>> _one(String search) =>
    Stream.value([_col('c1', 'Génétique')]);

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  double textScale = 1,
  HomeStats? stats,
  _Collections collections = _one,
  Stream<HomeStats>? statsStream,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      for (final p in ['/stats', '/study', '/import', '/collection/:id'])
        GoRoute(
          path: p,
          builder: (_, state) => Scaffold(body: Text('dest:${state.uri.path}')),
        ),
    ],
  );
  addTearDown(router.dispose);
  final List<Override> overrides = [
    currentUserProvider.overrideWithValue(null),
    homeStatsProvider.overrideWith(
      (ref) => statsStream ?? Stream.value(stats ?? _stats()),
    ),
    homeCollectionsProvider.overrideWith((ref, s) => collections(s)),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      retry: (_, _) => null,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

final _list = find.byType(Scrollable).first;

void main() {
  testWidgets('hero shows the due count and a study CTA', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(find.text('734'), findsOneWidget);
    expect(find.text('cartes à revoir'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-study-cta')), findsOneWidget);
    expect(find.text('Étudier maintenant'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('home-study-cta'))).label,
      'Commencer une session de 734 cartes',
    );
    semantics.dispose();
  });

  testWidgets('hero uses the singular for one card', (tester) async {
    await _pump(tester, stats: _stats(due: 1));
    expect(find.text('carte à revoir'), findsOneWidget);
    expect(find.text('cartes à revoir'), findsNothing);
  });

  testWidgets('zero due shows up-to-date and no CTA', (tester) async {
    await _pump(tester, stats: _stats(due: 0));
    expect(find.text('Tout est à jour'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-study-cta')), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('stats row shows streak and success rate', (tester) async {
    await _pump(tester);
    expect(find.text('12 j'), findsOneWidget);
    expect(find.text('de série'), findsOneWidget);
    expect(find.text('82 %'), findsOneWidget);
    expect(find.text('de réussite'), findsOneWidget);
  });

  testWidgets('search is debounced and only the final term is requested', (
    tester,
  ) async {
    final requested = <String>[];
    await _pump(
      tester,
      collections: (s) {
        requested.add(s);
        return _one(s);
      },
    );
    expect(requested, ['']);
    for (final text in ['g', 'gé', 'gén']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(requested, ['']);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(requested, ['', 'gén']);
  });

  testWidgets('previous results stay while the next search loads', (
    tester,
  ) async {
    final pending = StreamController<List<CollectionListItem>>();
    addTearDown(pending.close);
    await _pump(
      tester,
      collections: (s) => s.isEmpty ? _one(s) : pending.stream,
    );
    await tester.enterText(find.byType(TextField), 'x');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Génétique'), findsOneWidget);
    expect(find.byType(SkeletonBox), findsNothing);
    pending.add([_col('c2', 'Chimie')]);
    await tester.pump();
    expect(find.text('Chimie'), findsOneWidget);
    expect(find.text('Génétique'), findsNothing);
  });

  testWidgets('no collections and no results are distinct empty states', (
    tester,
  ) async {
    await _pump(tester, collections: (_) => Stream.value(const []));
    expect(find.text('Aucune collection'), findsOneWidget);
    expect(find.text('Importer un fichier CSV'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Aucun résultat'), findsOneWidget);
    expect(find.textContaining('zzz', skipOffstage: false), findsWidgets);
    expect(find.text('Aucune collection'), findsNothing);
    expect(find.text('Importer un fichier CSV'), findsNothing);
  });

  testWidgets('error state retries and never shows the exception', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      collections: (_) {
        calls++;
        return Stream.error(Exception('boom-secret'));
      },
    );
    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.textContaining('boom-secret'), findsNothing);
    final before = calls;
    await tester.ensureVisible(find.text('Réessayer'));
    await tester.pump();
    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    await tester.pump();
    expect(calls, greaterThan(before));
    expect(find.textContaining('boom-secret'), findsNothing);
  });

  testWidgets('stats error shows a retry state without exception text', (
    tester,
  ) async {
    await _pump(tester, statsStream: Stream.error(Exception('stats-secret')));
    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.textContaining('stats-secret'), findsNothing);
  });

  testWidgets('disabled collections get their own section', (tester) async {
    await _pump(
      tester,
      collections: (_) => Stream.value([
        _col('a', 'Active'),
        _col('b', 'Éteinte', disabled: true),
      ]),
    );
    await tester.scrollUntilVisible(
      find.text('DÉSACTIVÉ(S)'),
      200,
      scrollable: _list,
    );
    expect(find.text('DÉSACTIVÉ(S)'), findsOneWidget);
    expect(find.byType(DisabledBadge), findsOneWidget);
    expect(find.byKey(const ValueKey('collection-tile-a')), findsOneWidget);
  });

  const longTitle =
      'Biologie moléculaire avancée et génétique des populations humaines';
  for (final (label, size, scale) in [
    ('320x568', const Size(320, 568), 1.0),
    ('360x800', const Size(360, 800), 1.0),
    ('360x800 at 2.0 text scale', const Size(360, 800), 2.0),
    ('320x568 at 2.0 text scale', const Size(320, 568), 2.0),
    ('800x1000 two columns', const Size(800, 1000), 1.0),
  ]) {
    testWidgets('long title is shown in full without overflow: $label', (
      tester,
    ) async {
      expect(longTitle.length, greaterThanOrEqualTo(60));
      await _pump(
        tester,
        size: size,
        textScale: scale,
        collections: (_) => Stream.value([
          _col('c1', longTitle),
          _col('c2', 'Autre', disabled: true),
        ]),
      );
      await tester.scrollUntilVisible(
        find.text(longTitle),
        200,
        scrollable: _list,
      );
      expect(find.text(longTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  // Colonnes: largeur réellement disponible et échelle du texte, pas la fenêtre.
  for (final (label, size, scale, columns) in [
    ('360x800', const Size(360, 800), 1.0, 1),
    ('600x960', const Size(600, 960), 1.0, 1),
    ('880x1408', const Size(880, 1408), 1.0, 2),
    // Taille de police système réelle de la tablette du propriétaire. Ces tests
    // n'ont pas de rail: 800 de large donne les 736 du portrait réel (880).
    ('800x1408 at 1.15 text scale', const Size(800, 1408), 1.15, 2),
    ('1408x880', const Size(1408, 880), 1.0, 3),
    ('1408x880 at 1.15 text scale', const Size(1408, 880), 1.15, 3),
    ('880x1408 at 2.0 text scale', const Size(880, 1408), 2.0, 1),
  ]) {
    testWidgets('collections use $columns column(s) at $label', (tester) async {
      await _pump(
        tester,
        size: size,
        textScale: scale,
        collections: (_) => Stream.value([
          for (var i = 0; i < 6; i++) _col('c$i', 'Collection $i'),
        ]),
      );
      final tiles = [
        for (var i = 0; i < 6; i++) find.byKey(ValueKey('collection-tile-c$i')),
      ].where((f) => f.evaluate().isNotEmpty);
      final lefts = {for (final t in tiles) tester.getTopLeft(t).dx};
      expect(lefts.length, columns);
      // Aucune carte plus étroite que le minimum: pas de mot coupé.
      for (final card in find.byType(Card).evaluate().skip(3)) {
        // Téléphone: une seule colonne, sans minimum.
        if (size.width < 600) break;
        expect(
          card.size!.width,
          greaterThanOrEqualTo(290 * (scale > 1 ? scale : 1)),
        );
      }
    });
  }

  for (final (label, size, scale, beside) in [
    ('880x1408', const Size(880, 1408), 1.0, true),
    ('360x800', const Size(360, 800), 1.0, false),
    ('880x1408 at 2.0 text scale', const Size(880, 1408), 2.0, false),
  ]) {
    testWidgets('hero is beside the stats only when there is room: $label', (
      tester,
    ) async {
      await _pump(tester, size: size, textScale: scale);
      final hero = tester.getTopLeft(find.text('734'));
      final streak = tester.getTopLeft(find.text('12 j'));
      expect(streak.dx > hero.dx + 200, beside);
      if (beside) {
        // Même hauteur totale: le bas des statistiques rejoint celui du héros.
        final heroCard = find.ancestor(
          of: find.text('734'),
          matching: find.byType(Card),
        );
        final successCard = find.ancestor(
          of: find.text('82 %'),
          matching: find.byType(Card),
        );
        expect(
          tester.getBottomLeft(heroCard).dy,
          closeTo(tester.getBottomLeft(successCard).dy, 0.5),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('navigation uses the expected destinations', (tester) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Voir les statistiques'));
    await tester.pumpAndSettle();
    expect(find.text('dest:/stats'), findsOneWidget);

    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('home-study-cta')));
    await tester.pumpAndSettle();
    expect(find.text('dest:/study'), findsOneWidget);

    await _pump(tester);
    await tester.tap(find.text('Importer CSV'));
    await tester.pumpAndSettle();
    expect(find.text('dest:/import'), findsOneWidget);

    await _pump(tester);
    await tester.tap(find.text('Génétique'));
    await tester.pumpAndSettle();
    expect(find.text('dest:/collection/c1'), findsOneWidget);
  });
}
