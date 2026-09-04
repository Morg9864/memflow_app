import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/app/providers.dart';
import 'package:memflow/data/sync/sync_service.dart';
import 'package:memflow/features/profile/profile_screen.dart';
import 'package:memflow/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the offline state and pending changes count', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      const SyncStatus(state: SyncState.offline, pendingCount: 3),
    );

    expect(find.byKey(const ValueKey('sync-status-panel')), findsOneWidget);
    expect(find.text('Hors ligne'), findsOneWidget);
    expect(find.textContaining('3 modifications en attente'), findsOneWidget);
    expect(find.textContaining('dès la reconnexion'), findsOneWidget);
  });

  testWidgets('shows when the local queue is empty while offline', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      const SyncStatus(state: SyncState.offline, pendingCount: 0),
    );

    expect(find.text('Hors ligne'), findsOneWidget);
    expect(
      find.textContaining('Aucune modification en attente'),
      findsOneWidget,
    );
  });

  testWidgets('shows the last sync time and manual sync action', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      SyncStatus(
        state: SyncState.idle,
        pendingCount: 0,
        lastSyncedAt: DateTime(2026, 9, 4, 14, 5),
      ),
    );

    expect(find.textContaining('Dernière synchronisation'), findsOneWidget);
    expect(find.textContaining('04/09/2026 à 14:05'), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-now-button')), findsOneWidget);
  });

  testWidgets('explains a server synchronization failure', (tester) async {
    await _pumpProfile(
      tester,
      const SyncStatus(
        state: SyncState.error,
        pendingCount: 2,
        failureKind: SyncFailureKind.server,
        errorMessage: 'Le serveur a refusé la synchronisation.',
      ),
    );

    expect(find.text('Synchronisation impossible'), findsOneWidget);
    expect(
      find.text('Le serveur a refusé la synchronisation.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpProfile(WidgetTester tester, SyncStatus status) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        currentUserProvider.overrideWithValue(null),
        syncStatusProvider.overrideWith((ref) => Stream.value(status)),
      ],
      child: MaterialApp.router(
        theme: ThemeData(useMaterial3: true),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
