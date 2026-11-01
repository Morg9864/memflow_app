// Regression journeys through the real router and screens. They catch broken
// wiring (routes, extras, navigation) that screen-level tests cannot see.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/features/auth/auth_screen.dart';
import 'package:memflow/features/collections/collection_detail_screen.dart';
import 'package:memflow/features/home/home_screen.dart';
import 'package:memflow/features/study/session_summary_screen.dart';
import 'package:memflow/domain/models/models.dart';

import '../support/app_harness.dart';
import '../support/screen_cases.dart' show revealing;

void main() {
  testWidgets(
    'home > collection > session > rate > summary > back to the collection',
    (tester) async {
      final repo = FakeRepository();
      await pumpApp(tester, repo);
      expect(find.byType(HomeScreen), findsOneWidget);

      await openModeSheetFromHome(tester);
      expect(find.text('Mode de session'), findsOneWidget);
      await tester.tap(find.text('QCM'));
      await tester.pumpAndSettle();
      expect(repo.log, ['start:multipleChoice']);
      expect(find.text('Question a ?'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);

      // The review write is held: the session must not advance before it is
      // durable (rating persisted first, then the next card).
      repo.submitGate = Completer<void>();
      await tester.tap(find.text('Bonne réponse'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Correct'));
      await tester.tap(find.text('Correct'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(repo.log.last, 'submit:a:good');
      expect(find.text('1/2'), findsOneWidget, reason: 'still on card 1');
      expect(find.text('Question a ?'), findsOneWidget);

      repo.submitGate!.complete();
      await tester.pumpAndSettle();
      expect(repo.log.sublist(1), ['submit:a:good', 'submitted:a', 'save:1']);
      expect(find.text('2/2'), findsOneWidget);
      expect(find.text('Question b ?'), findsOneWidget);

      repo.submitGate = null;
      await tester.tap(find.text('Bonne réponse'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Facile'));
      await tester.tap(find.text('Facile'));
      await tester.pumpAndSettle();
      expect(find.byType(SessionSummaryScreen), findsOneWidget);
      expect(find.text('Session terminée'), findsOneWidget);

      await tester.ensureVisible(find.text('Retour à la collection'));
      await tester.tap(find.text('Retour à la collection'));
      await tester.pumpAndSettle();
      expect(find.byType(CollectionDetailScreen), findsOneWidget);
      expect(find.byType(SessionSummaryScreen), findsNothing);
    },
  );

  testWidgets('summary > "Refaire une session" opens the mode sheet again', (
    tester,
  ) async {
    final repo = FakeRepository();
    final (router, _) = await pumpApp(tester, repo);
    router.go(
      '/session-summary',
      extra: SessionSummary(
        collectionId: 'c1',
        deckId: 'd0',
        deckTitle: 'Biologie',
        totalCards: 2,
        reviewCounts: const {ReviewResult.good: 2},
        correctCount: 2,
        incorrectCount: 0,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Refaire une session'));
    await tester.tap(find.text('Refaire une session'));
    await tester.pumpAndSettle();
    expect(find.text('Mode de session'), findsOneWidget);
  });

  group('dismissing the mode sheet exits cleanly', () {
    void expectNoLoadingResidue() {
      expect(find.text('Mode de session'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Préparation'), findsNothing);
    }

    testWidgets('pushed from the collection: back on the collection', (
      tester,
    ) async {
      await pumpApp(tester, FakeRepository());
      await openModeSheetFromHome(tester);
      // System back closes the sheet (a phone sheet has no close button).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectNoLoadingResidue();
      expect(find.byType(CollectionDetailScreen), findsOneWidget);
    });

    testWidgets('deep link with nothing to pop: falls back to the collection', (
      tester,
    ) async {
      final (router, _) = await pumpApp(tester, FakeRepository());
      router.go('/study?collectionId=c1');
      await tester.pumpAndSettle();
      expect(find.text('Mode de session'), findsOneWidget);
      // System back closes the sheet (a phone sheet has no close button).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectNoLoadingResidue();
      expect(find.byType(CollectionDetailScreen), findsOneWidget);
    });
  });

  testWidgets('profile > "Se déconnecter" returns to the auth screen', (
    tester,
  ) async {
    final (router, _) = await pumpApp(tester, FakeRepository());
    router.go('/profile');
    await tester.pumpAndSettle();
    await revealing(tester, find.text('Se déconnecter'));
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/auth');
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
