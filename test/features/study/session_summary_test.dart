import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/features/study/session_summary_screen.dart';
import 'package:memflow/theme/app_theme.dart';

const _title =
    'Introduction à la biologie moléculaire et à la génétique humaine ok';

SessionSummary _summary({
  String? collectionId = 'bio',
  String? deckId = 'd1',
  int incorrect = 3,
  int total = 12,
  String title = _title,
}) => SessionSummary(
  collectionId: collectionId,
  deckId: deckId,
  deckTitle: title,
  totalCards: total,
  correctCount: total - incorrect,
  incorrectCount: incorrect,
  duration: const Duration(minutes: 4, seconds: 5),
  reviewCounts: const {
    ReviewResult.again: 2,
    ReviewResult.hard: 1,
    ReviewResult.good: 6,
    ReviewResult.easy: 3,
  },
);

void _setView(WidgetTester tester, Size size, [double textScale = 1.0]) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// Pumps the summary; the returned list records every location reached.
Future<List<String>> _pump(WidgetTester tester, SessionSummary summary) async {
  final visited = <String>[];
  GoRoute page(String path) => GoRoute(
    path: path,
    builder: (_, state) {
      visited.add(state.uri.toString());
      return Scaffold(body: Text('page $path'));
    },
  );
  final router = GoRouter(
    initialLocation: '/summary',
    routes: [
      GoRoute(
        path: '/summary',
        builder: (_, _) => SessionSummaryScreen(summary: summary),
      ),
      page('/'),
      page('/collection/:id'),
      page('/study'),
      page('/study/errors'),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  await tester.pumpAndSettle();
  return visited;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pump();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  const viewports = <(String, Size, double)>[
    ('320x568', Size(320, 568), 1.0),
    ('360x800', Size(360, 800), 1.0),
    ('360x800 @2.0', Size(360, 800), 2.0),
  ];

  for (final (name, size, scale) in viewports) {
    testWidgets('no overflow, actions reachable at $name', (tester) async {
      _setView(tester, size, scale);
      await _pump(tester, _summary());
      expect(tester.takeException(), isNull);
      for (final label in [
        'cartes vues',
        'Revoir mes erreurs (3)',
        'Retour à la collection',
        'Refaire une session',
        'Accueil',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: label);
        final rect = tester.getRect(find.text(label));
        expect(rect.bottom, lessThanOrEqualTo(size.height), reason: label);
        expect(rect.top, greaterThanOrEqualTo(0), reason: label);
      }
    });
  }

  testWidgets('zero cards does not throw', (tester) async {
    _setView(tester, const Size(360, 800));
    await _pump(tester, _summary(total: 0, incorrect: 0));
    expect(tester.takeException(), isNull);
    expect(find.text('0/0'), findsOneWidget);
  });

  testWidgets('shows the focal value and title header', (tester) async {
    _setView(tester, const Size(360, 800));
    await _pump(tester, _summary());
    expect(find.text('Session terminée'), findsOneWidget);
    expect(find.text('9/12'), findsOneWidget);
    expect(find.text('précision objective'), findsOneWidget);
    expect(find.text('12 cartes · 4m 05s'), findsOneWidget);
    expect(find.text(_title), findsOneWidget);
  });

  testWidgets('Revoir mes erreurs only when there are errors', (tester) async {
    _setView(tester, const Size(360, 800));
    await _pump(tester, _summary(incorrect: 0));
    expect(find.textContaining('Revoir mes erreurs'), findsNothing);
  });

  testWidgets('Revoir mes erreurs goes to /study/errors', (tester) async {
    _setView(tester, const Size(360, 800));
    final visited = await _pump(tester, _summary());
    await _tapText(tester, 'Revoir mes erreurs (3)');
    expect(visited.last, '/study/errors');
  });

  testWidgets('Retour à la collection goes to the collection', (tester) async {
    _setView(tester, const Size(360, 800));
    final visited = await _pump(tester, _summary());
    await _tapText(tester, 'Retour à la collection');
    expect(visited.last, '/collection/bio');
  });

  testWidgets('Retour with null collectionId goes to /', (tester) async {
    _setView(tester, const Size(360, 800));
    final visited = await _pump(tester, _summary(collectionId: null));
    await _tapText(tester, 'Retour à la collection');
    expect(visited.last, '/');
  });

  testWidgets('Refaire une session targets the deck, else the collection', (
    tester,
  ) async {
    _setView(tester, const Size(360, 800));
    var visited = await _pump(tester, _summary());
    await _tapText(tester, 'Refaire une session');
    expect(visited.last, '/study?deckId=d1');

    visited = await _pump(tester, _summary(deckId: null));
    await _tapText(tester, 'Refaire une session');
    expect(visited.last, '/study?collectionId=bio');
  });

  testWidgets('Accueil goes to /', (tester) async {
    _setView(tester, const Size(360, 800));
    final visited = await _pump(tester, _summary());
    await _tapText(tester, 'Accueil');
    expect(visited.last, '/');
  });
}
