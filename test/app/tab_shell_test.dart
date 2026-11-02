import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/app/providers.dart';
import 'package:memflow/app/router.dart';
import 'package:memflow/data/repositories/app_repository.dart';
import 'package:memflow/data/sync/sync_service.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/auth_service.dart';
import 'package:memflow/domain/services/card_mode_service.dart';
import 'package:memflow/features/auth/auth_screen.dart';
import 'package:memflow/features/collections/collection_detail_screen.dart';
import 'package:memflow/features/collections/collection_due_cards_screen.dart';
import 'package:memflow/features/home/home_screen.dart';
import 'package:memflow/features/import/import_screen.dart';
import 'package:memflow/features/profile/profile_screen.dart';
import 'package:memflow/features/profile/settings_screen.dart';
import 'package:memflow/features/stats/stats_screen.dart';
import 'package:memflow/features/study/study_screen.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _user = User(
  id: 'u1',
  appMetadata: {},
  userMetadata: {
    'adult_attested_at': '2026-11-02T00:00:00Z',
    'accepted_terms_version': '2026-11-02',
  },
  aud: 'authenticated',
  createdAt: '2026-01-01',
);

class _FakeAuth implements AuthService {
  final _controller = StreamController<AuthState>.broadcast();
  Session? session = Session(
    accessToken: 't',
    tokenType: 'bearer',
    user: _user,
  );

  @override
  Session? get currentSession => session;
  @override
  User? get currentUser => session?.user;
  @override
  Stream<AuthState> get onAuthStateChange => _controller.stream;

  void emit(AuthChangeEvent event) =>
      _controller.add(AuthState(event, session));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepository implements AppRepository {
  // The study screen only needs to be on screen: its session never loads.
  @override
  Future<StudyModeAvailability> studyModeAvailability({
    String? collectionId,
    String? deckId,
  }) => Completer<StudyModeAvailability>().future;

  @override
  Stream<int> watchDueCardsForCollectionRevision() => const Stream.empty();

  @override
  Future<PaginatedSlice<FlashcardDueItem>> fetchDueCardsForCollectionPage({
    required String collectionId,
    required int offset,
    required int limit,
  }) async => const PaginatedSlice(items: [], totalCount: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CollectionListItem _col(String id) => CollectionListItem(
  id: id,
  name: 'Collection $id',
  description: '',
  icon: 'A',
  totalCards: 10,
  cardsDone: 1,
  dueCards: 2,
  color: 0xFF2E7D6B,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  errorCount: 0,
  isDisabled: false,
);

const _stats = StatisticsOverview(
  streakDays: 1,
  totalReviews: 1,
  successRate: .5,
  studyDays: 1,
  heatmap: [],
  levelProgress: [],
  successTrend: [],
  collectionProgress: [],
  modeProgress: [],
  difficultCards: [],
);

Future<(GoRouter, _FakeAuth)> _pump(
  WidgetTester tester, {
  Size size = const Size(599, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = _FakeAuth();
  final collections = [for (var i = 0; i < 30; i++) _col('c$i')];
  final List<Override> overrides = [
    sharedPreferencesProvider.overrideWithValue(prefs),
    authServiceProvider.overrideWithValue(auth),
    currentUserProvider.overrideWithValue(_user),
    appRepositoryProvider.overrideWithValue(_FakeRepository()),
    homeStatsProvider.overrideWith(
      (ref) => Stream.value(
        const HomeStats(
          streakDays: 1,
          successRate: .5,
          dueCards: 3,
          totalCardsSeen: 4,
        ),
      ),
    ),
    homeCollectionsProvider.overrideWith(
      (ref, s) => Stream.value(
        collections.where((c) => c.name.toLowerCase().contains(s)).toList(),
      ),
    ),
    statisticsOverviewProvider.overrideWith((ref) => Stream.value(_stats)),
    collectionProvider.overrideWith((ref, id) => Stream.value(_col(id))),
    collectionDecksProvider.overrideWith(
      (ref, id) => Stream.value(const <DeckListItem>[]),
    ),
    syncStatusProvider.overrideWith(
      (ref) => Stream.value(
        const SyncStatus(state: SyncState.idle, pendingCount: 0),
      ),
    ),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: ref.watch(routerProvider),
          builder: (context, child) => AdaptiveTheme(child: child!),
        ),
      ),
    ),
  );
  auth.emit(AuthChangeEvent.signedIn);
  await tester.pumpAndSettle();
  final router = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  ).read(routerProvider);
  return (router, auth);
}

Future<void> _go(WidgetTester tester, GoRouter router, String path) async {
  router.go(path);
  await tester.pumpAndSettle();
}

Future<void> _tapBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Retour').last);
  await tester.pumpAndSettle();
}

String _searchText(WidgetTester t) =>
    t.widget<EditableText>(find.byType(EditableText)).controller.text;

void main() {
  final bar = find.byType(NavigationBar);
  final rail = find.byType(NavigationRail);
  const phone = Size(360, 800);
  const tablet = Size(880, 1408);

  testWidgets('phone width: bar and no rail', (tester) async {
    await _pump(tester, size: phone);
    expect(bar, findsOneWidget);
    expect(rail, findsNothing);
  });

  testWidgets('tablet width: rail and no bar', (tester) async {
    await _pump(tester, size: tablet);
    expect(rail, findsOneWidget);
    expect(bar, findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).bottomNavigationBar,
      isNull,
    );
  });

  testWidgets('tablet width: rail targets are large and labelled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, size: tablet);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    for (final label in ['Accueil', 'Stats', 'Importer', 'Profil']) {
      expect(
        find.descendant(of: rail, matching: find.text(label)),
        findsOneWidget,
      );
    }
    handle.dispose();
  });

  for (final (name, size, nav) in [
    ('bar', phone, NavigationBar),
    ('rail', tablet, NavigationRail),
  ]) {
    testWidgets('$name: tapping switches tab and keeps tab state', (
      tester,
    ) async {
      await _pump(tester, size: size);
      await tester.enterText(find.byType(TextField), 'keep me');
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(nav), matching: find.text('Stats')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StatisticsScreen), findsOneWidget);
      await tester.tap(
        find.descendant(of: find.byType(nav), matching: find.text('Accueil')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(_searchText(tester), 'keep me');
    });

    testWidgets('$name: re-tapping the current tab returns to its root', (
      tester,
    ) async {
      final (router, _) = await _pump(tester, size: size);
      router.push('/collection/c1');
      await tester.pumpAndSettle();
      expect(find.byType(CollectionDetailScreen), findsOneWidget);
      await tester.tap(
        find.descendant(of: find.byType(nav), matching: find.text('Accueil')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(CollectionDetailScreen), findsNothing);
    });
  }

  testWidgets('tablet type step applies from 600 wide, not below', (
    tester,
  ) async {
    double? bodyLarge;
    Future<double> sizeAt(double w) async {
      tester.view.physicalSize = Size(w, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => AdaptiveTheme(child: child!),
          home: Builder(
            builder: (context) {
              bodyLarge = Theme.of(context).textTheme.bodyLarge!.fontSize;
              return const SizedBox();
            },
          ),
        ),
      );
      return bodyLarge!;
    }

    final phoneSize = AppTheme.light().textTheme.bodyLarge!.fontSize!;
    expect(await sizeAt(599), phoneSize);
    expect(await sizeAt(600), greaterThan(phoneSize));
    expect(await sizeAt(880), AppTheme.tablet().textTheme.bodyLarge!.fontSize);
  });

  testWidgets(
    'Home search text and scroll survive a round trip through Stats',
    (tester) async {
      await _pump(tester);
      await tester.enterText(find.byType(TextField), 'collection c');
      await tester.pumpAndSettle();
      expect(_searchText(tester), 'collection c');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      final before = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(before, greaterThan(0));

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();
      expect(find.byType(StatisticsScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      await tester.tap(find.text('Accueil'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        before,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(_searchText(tester), 'collection c');
    },
  );

  testWidgets(
    'tab bar is visible on tabs and collection, hidden on study/auth',
    (tester) async {
      final (router, _) = await _pump(tester);
      for (final path in [
        '/',
        '/stats',
        '/import',
        '/profile',
        '/collection/x',
      ]) {
        await _go(tester, router, path);
        expect(bar, findsOneWidget, reason: path);
      }
      router.go('/study');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // spinner never settles
      expect(find.byType(StudyScreen), findsOneWidget);
      expect(bar, findsNothing);
      await _go(tester, router, '/');
      router.push('/study');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(bar, findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(bar, findsOneWidget);
    },
  );

  testWidgets('direct deep links have a working back button', (tester) async {
    final (router, _) = await _pump(tester);
    await _go(tester, router, '/collection/x');
    expect(find.byType(CollectionDetailScreen), findsOneWidget);
    await _tapBack(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    await _go(tester, router, '/settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
    await _tapBack(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('due-cards screen back works pushed imperatively and by URL', (
    tester,
  ) async {
    final (router, _) = await _pump(tester);
    await _go(tester, router, '/collection/c1');
    await tester.tap(find.text('Voir les échéances'));
    await tester.pumpAndSettle();
    expect(find.byType(CollectionDueCardsScreen), findsOneWidget);
    await _tapBack(tester);
    expect(find.byType(CollectionDetailScreen), findsOneWidget);
    expect(find.byType(CollectionDueCardsScreen), findsNothing);

    await _go(tester, router, '/collection/c1/due-cards?name=A');
    expect(find.byType(CollectionDueCardsScreen), findsOneWidget);
    await _tapBack(tester);
    expect(find.byType(CollectionDetailScreen), findsOneWidget);
  });

  testWidgets('Accueil keeps the collection on the Home stack', (tester) async {
    final (router, _) = await _pump(tester);
    await _go(tester, router, '/');
    router.push('/collection/c1');
    await tester.pumpAndSettle();
    expect(find.byType(CollectionDetailScreen), findsOneWidget);

    router.go('/import');
    await tester.pumpAndSettle();
    expect(find.byType(ImportScreen), findsOneWidget);

    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
    expect(find.byType(CollectionDetailScreen), findsOneWidget);

    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(CollectionDetailScreen), findsNothing);
  });

  testWidgets('sign-out destroys tab state; next sign-in starts clean', (
    tester,
  ) async {
    final (router, auth) = await _pump(tester);
    await tester.enterText(find.byType(TextField), 'secret search');
    await tester.pumpAndSettle();

    auth.session = null;
    auth.emit(AuthChangeEvent.signedOut);
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/auth');
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(bar, findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(HomeScreen, skipOffstage: false), findsNothing);
    expect(find.text('secret search', skipOffstage: false), findsNothing);

    auth.session = Session(accessToken: 't2', tokenType: 'bearer', user: _user);
    auth.emit(AuthChangeEvent.signedIn);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('secret search', skipOffstage: false), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text ?? '',
      isEmpty,
    );
  });

  testWidgets('unknown URL renders the 404 screen', (tester) async {
    final (router, _) = await _pump(tester);
    await _go(tester, router, '/nope');
    expect(find.text('Page introuvable'), findsOneWidget);
  });
}
