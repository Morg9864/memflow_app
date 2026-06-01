import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/features/navigation/not_found_screen.dart';

void main() {
  testWidgets('unknown routes render the dedicated 404 screen', (tester) async {
    final router = GoRouter(
      initialLocation: '/missing-page',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Accueil'))),
        ),
      ],
      errorBuilder: (context, state) =>
          NotFoundScreen(requestedPath: state.uri.toString()),
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Page introuvable'), findsOneWidget);
    expect(find.text('Chemin demandé: /missing-page'), findsOneWidget);

    await tester.tap(find.text('Retour à l’accueil'));
    await tester.pumpAndSettle();

    expect(find.text('Accueil'), findsOneWidget);
  });
}
