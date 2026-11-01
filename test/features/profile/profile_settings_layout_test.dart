import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/app/providers.dart';
import 'package:memflow/data/sync/sync_service.dart';
import 'package:memflow/domain/services/auth_service.dart';
import 'package:memflow/features/profile/profile_screen.dart';
import 'package:memflow/features/profile/settings_screen.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _longName =
    'Maximilienne-Alexandrine de la Tour-Saint-Barthélemy-Montmorency';
const _longEmail =
    'maximilienne.alexandrine.de.la.tour.saint.barthelemy@'
    'un-domaine-vraiment-tres-long-pour-tester.example.org';

const _sizes = <(String, Size, double)>[
  ('320x568', Size(320, 568), 1.0),
  ('360x800', Size(360, 800), 1.0),
  ('360x800 @2.0x', Size(360, 800), 2.0),
];

class _FakeAuth implements AuthService {
  _FakeAuth(this.user);

  final User? user;
  final signOutGate = Completer<void>();
  final controller = StreamController<AuthState>.broadcast();
  bool signOutCalled = false;
  String? updatedName;

  @override
  User? get currentUser => user;

  @override
  Stream<AuthState> get onAuthStateChange => controller.stream;

  @override
  Future<void> signOut() {
    signOutCalled = true;
    return signOutGate.future;
  }

  @override
  Future<void> updateDisplayName(String name) async => updatedName = name;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

User _user({String name = _longName, String email = _longEmail}) => User(
  id: 'u1',
  appMetadata: const {},
  userMetadata: {'display_name': name},
  aud: 'authenticated',
  createdAt: '2026-01-01',
  email: email,
);

Future<_FakeAuth> _pump(
  WidgetTester tester, {
  required Widget screen,
  Size size = const Size(360, 800),
  double textScale = 1.0,
  SyncStatus status = const SyncStatus(state: SyncState.idle, pendingCount: 0),
  User? user,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final auth = _FakeAuth(user);
  addTearDown(auth.controller.close);
  final router = GoRouter(
    initialLocation: '/page',
    routes: [
      GoRoute(path: '/page', builder: (context, state) => screen),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        authServiceProvider.overrideWithValue(auth),
        syncStatusProvider.overrideWith((ref) => Stream.value(status)),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

Future<void> _expectReachable(WidgetTester tester, Finder finder) async {
  // ListView builds lazily: scroll until the row exists and is on screen.
  await tester.scrollUntilVisible(
    finder,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  final rect = tester.getRect(finder.first);
  final view = Offset.zero & tester.view.physicalSize;
  expect(view.contains(rect.center), isTrue, reason: '$finder off screen');
}

const _profileActions = [
  'Paramètres du compte',
  'Objectif quotidien',
  'Synchroniser maintenant',
  'Exporter les cartes en CSV',
  'Version app',
  'Politique de confidentialité',
  "Conditions d'utilisation",
  'Mentions légales',
  'Licences open-source',
  'Se déconnecter',
  'Demander la suppression de mon compte',
];

const _settingsActions = [
  "Nom d'affichage",
  'Adresse email',
  'Mot de passe',
  'Cartes par session',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile and settings stay within the form column on a tablet', (
    tester,
  ) async {
    for (final screen in [const ProfileScreen(), const SettingsScreen()]) {
      await _pump(
        tester,
        screen: screen,
        size: const Size(880, 1408),
        user: _user(),
      );
      expect(
        tester.getSize(find.byType(ListView).first).width,
        lessThanOrEqualTo(AppTheme.formMaxWidth),
      );
    }
  });

  for (final (label, size, scale) in _sizes) {
    group('at $label', () {
      testWidgets('profile lays out with long name and email', (tester) async {
        await _pump(
          tester,
          screen: const ProfileScreen(),
          size: size,
          textScale: scale,
          user: _user(),
        );
        expect(tester.takeException(), isNull);
        expect(find.text(_longName), findsOneWidget);
        expect(find.text(_longEmail), findsOneWidget);
        for (final action in _profileActions) {
          await _expectReachable(tester, find.text(action));
        }
        expect(tester.takeException(), isNull);
      });

      for (final state in SyncState.values) {
        testWidgets('profile lays out in sync state ${state.name}', (
          tester,
        ) async {
          await _pump(
            tester,
            screen: const ProfileScreen(),
            size: size,
            textScale: scale,
            user: _user(),
            status: SyncStatus(
              state: state,
              pendingCount: 12,
              lastSyncedAt: DateTime(2026, 9, 4, 14, 5),
              errorMessage: state == SyncState.error
                  ? 'Le serveur a refusé la synchronisation, '
                        'avec un message volontairement très long.'
                  : null,
            ),
          );
          expect(tester.takeException(), isNull);
          await _expectReachable(
            tester,
            find.byKey(const ValueKey('sync-status-panel')),
          );
          await _expectReachable(
            tester,
            find.byKey(const ValueKey('sync-now-button')),
          );
        });
      }

      testWidgets('settings lays out with long name and email', (tester) async {
        await _pump(
          tester,
          screen: const SettingsScreen(),
          size: size,
          textScale: scale,
          user: _user(),
        );
        expect(tester.takeException(), isNull);
        expect(find.text(_longEmail), findsOneWidget);
        for (final action in _settingsActions) {
          await _expectReachable(tester, find.text(action));
        }
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('profile without a user hides account and session rows', (
    tester,
  ) async {
    await _pump(tester, screen: const ProfileScreen());
    expect(find.text('Paramètres du compte'), findsNothing);
    expect(find.text('Se déconnecter'), findsNothing);
    expect(find.text('Objectif quotidien'), findsOneWidget);
    expect(find.text('Licences open-source'), findsOneWidget);
  });

  testWidgets('every row is at least 48 tall', (tester) async {
    for (final screen in const [ProfileScreen(), SettingsScreen()]) {
      await _pump(
        tester,
        screen: screen,
        size: const Size(320, 568),
        textScale: 2.0,
        user: _user(),
      );
      for (final title
          in screen is ProfileScreen
              ? _profileActions.where((t) => t != 'Synchroniser maintenant')
              : _settingsActions) {
        await _expectReachable(tester, find.text(title));
        final tile = find.ancestor(
          of: find.text(title),
          matching: find.byType(ListTile),
        );
        expect(
          tester.getSize(tile).height,
          greaterThanOrEqualTo(48),
          reason: title,
        );
      }
    }
  });

  testWidgets('settings scrolls at a small size', (tester) async {
    await _pump(
      tester,
      screen: const SettingsScreen(),
      size: const Size(320, 568),
      textScale: 2.0,
      user: _user(),
    );
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-out and export are disabled while busy', (tester) async {
    final auth = await _pump(
      tester,
      screen: const ProfileScreen(),
      size: const Size(360, 2400),
      user: _user(),
    );
    ListTile tile(String title) =>
        tester.widget<ListTile>(find.widgetWithText(ListTile, title));

    expect(tile('Se déconnecter').enabled, isTrue);
    expect(tile('Exporter les cartes en CSV').enabled, isTrue);

    await _expectReachable(tester, find.text('Se déconnecter'));
    await tester.tap(find.text('Se déconnecter'));
    await tester.pump();

    expect(auth.signOutCalled, isTrue);
    expect(tile('Se déconnecter').enabled, isFalse);
    expect(tile('Exporter les cartes en CSV').enabled, isFalse);
    expect(tile('Demander la suppression de mon compte').enabled, isFalse);

    auth.signOutGate.complete();
    await tester.pumpAndSettle();
    expect(tile('Se déconnecter').enabled, isTrue);
  });

  testWidgets('back button has a tooltip and the edit icons are labelled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, screen: const SettingsScreen(), user: _user());
    expect(find.byTooltip('Retour'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Modifier')), findsWidgets);
    handle.dispose();
  });

  testWidgets('daily goal dialog can be reopened repeatedly', (tester) async {
    await _pump(tester, screen: const ProfileScreen(), user: _user());
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Objectif quotidien'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField), '${20 + i}');
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Objectif quotidien'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '42');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('42 cartes par jour'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings dialogs can be reopened repeatedly', (tester) async {
    final auth = await _pump(
      tester,
      screen: const SettingsScreen(),
      user: _user(),
    );
    for (final row in _settingsActions) {
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text(row));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget, reason: row);
        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull, reason: row);
      }
    }

    await tester.tap(find.text("Nom d'affichage"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(auth.updatedName, 'Alice');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
