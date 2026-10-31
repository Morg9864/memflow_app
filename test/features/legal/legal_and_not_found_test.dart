import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/features/legal/legal_document_screen.dart';
import 'package:memflow/features/navigation/not_found_screen.dart';
import 'package:memflow/theme/app_theme.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(360, 800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: screen,
    ),
  );
  await tester.pump();
}

void main() {
  const sizes = {
    '320x568': (Size(320, 568), 1.0),
    '360x800': (Size(360, 800), 1.0),
    '360x800 x2': (Size(360, 800), 2.0),
  };

  for (final e in sizes.entries) {
    for (final doc in LegalDocument.values) {
      testWidgets('legal ${doc.slug} has no exception at ${e.key}', (
        tester,
      ) async {
        await _pump(
          tester,
          LegalDocumentScreen(document: doc),
          size: e.value.$1,
          textScale: e.value.$2,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(SelectionArea), findsOneWidget);
      });
    }

    testWidgets('not found has no exception at ${e.key}', (tester) async {
      await _pump(
        tester,
        NotFoundScreen(requestedPath: '/${'très-long-chemin' * 8}'),
        size: e.value.$1,
        textScale: e.value.$2,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsOneWidget);
    });
  }

  testWidgets('not found scrolls to its buttons at 2.0 text scale', (
    tester,
  ) async {
    await _pump(
      tester,
      const NotFoundScreen(requestedPath: '/x'),
      size: const Size(320, 568),
      textScale: 2,
    );
    await tester.ensureVisible(find.text('Page précédente'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('deep-linked legal page has a working back button', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/legal/privacy',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Scaffold(body: Text('Profil')),
        ),
        GoRoute(
          path: '/legal/:doc',
          builder: (_, state) => LegalDocumentScreen(
            document: LegalDocument.fromSlug(state.pathParameters['doc']!),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retour'), findsOneWidget);
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('pushed legal page uses the default back button', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Profil')),
          routes: [
            GoRoute(
              path: 'legal',
              builder: (_, _) =>
                  const LegalDocumentScreen(document: LegalDocument.terms),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/legal');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retour'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });
}
