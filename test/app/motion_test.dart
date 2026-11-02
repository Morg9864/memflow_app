import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'dart:async';

import 'package:flutter/foundation.dart';
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
import 'package:memflow/features/collections/collection_detail_screen.dart';
import 'package:memflow/features/home/home_screen.dart';
import 'package:memflow/features/stats/stats_screen.dart';
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
  bool reduced = false,
}) async {
  tester.view.physicalSize = const Size(599, 900);
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: AdaptiveTheme(child: child!),
          ),
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

Finder get _shellFade => find
    .ancestor(of: find.byType(NavigationBar), matching: find.byType(Scaffold))
    .first;

FadeTransition _bodyFade(WidgetTester t) => t.widget<FadeTransition>(
  find.descendant(of: _shellFade, matching: find.byType(FadeTransition)).first,
);

Iterable<double> _routeOpacities(WidgetTester t, Type screen) => t
    .widgetList<FadeTransition>(
      find.ancestor(
        of: find.byType(screen),
        matching: find.byType(FadeTransition),
      ),
    )
    .map((f) => f.opacity.value);

void main() {
  testWidgets('theme: custom builder on Android, Cupertino on iOS', (
    tester,
  ) async {
    try {
      for (final (platform, cupertino) in [
        (TargetPlatform.android, false),
        (TargetPlatform.linux, false),
        (TargetPlatform.iOS, true),
        (TargetPlatform.macOS, true),
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        late ThemeData theme;
        await tester.pumpWidget(
          MaterialApp(
            // The static light theme freezes `platform` at first use.
            theme: AppTheme.light().copyWith(platform: platform),
            home: Builder(
              builder: (context) {
                theme = Theme.of(context);
                return const SizedBox();
              },
            ),
          ),
        );
        final builder = theme.pageTransitionsTheme.builders[theme.platform]!;
        expect(builder is CupertinoPageTransitionsBuilder, cupertino);
        if (!cupertino) {
          expect(builder.transitionDuration, AppMotion.standard);
          expect(builder.reverseTransitionDuration, AppMotion.standard);
        }
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  group('iOS page transition', () {
    Future<void> pushOnIos(WidgetTester tester, {required bool reduced}) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.iOS),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const Scaffold(body: Center(child: Text('next'))),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    double nextDx(WidgetTester tester) =>
        tester.getCenter(find.text('next')).dx - 200;

    testWidgets('slides without reduced motion', (tester) async {
      await pushOnIos(tester, reduced: false);
      expect(nextDx(tester), greaterThan(1));
    });

    testWidgets('reduced motion: no slide, and swipe-back still pops', (
      tester,
    ) async {
      await pushOnIos(tester, reduced: true);
      expect(nextDx(tester), 0);
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(4, 400), const Offset(320, 0));
      await tester.pumpAndSettle();
      expect(find.text('next'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  androidTest('page transition fades in and settles within standard', (
    tester,
  ) async {
    final (router, _) = await _pump(tester);
    router.push('/collection/c1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final mid = _routeOpacities(tester, CollectionDetailScreen);
    expect(mid.any((o) => o > 0 && o < 1), isTrue);
    await tester.pump(AppMotion.standard);
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      _routeOpacities(tester, CollectionDetailScreen).every((o) => o == 1),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(find.byType(CollectionDetailScreen), findsOneWidget);
  });

  androidTest('reduced motion: destination fully visible after one pump', (
    tester,
  ) async {
    final (router, _) = await _pump(tester, reduced: true);
    router.push('/collection/c1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(CollectionDetailScreen), findsOneWidget);
    expect(
      _routeOpacities(tester, CollectionDetailScreen).every((o) => o == 1),
      isTrue,
    );
  });

  for (final reduced in [false, true]) {
    androidTest('dialogs and sheets still open and settle (reduced=$reduced)', (
      tester,
    ) async {
      await _pump(tester, reduced: reduced);
      final context = tester.element(find.byType(HomeScreen));
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('dialog body')),
      );
      await tester.pumpAndSettle();
      expect(find.text('dialog body'), findsOneWidget);
      Navigator.of(tester.element(find.text('dialog body'))).pop();
      await tester.pumpAndSettle();
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => const SizedBox(height: 80, child: Text('sheet body')),
      );
      await tester.pumpAndSettle();
      expect(find.text('sheet body'), findsOneWidget);
    });
  }

  testWidgets('tab fade: partial midway, settled after fast', (tester) async {
    await _pump(tester);
    expect(_bodyFade(tester).opacity.value, 1);
    await tester.tap(find.text('Stats'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final mid = _bodyFade(tester).opacity.value;
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    await tester.pump(AppMotion.fast);
    expect(_bodyFade(tester).opacity.value, 1);
    expect(find.byType(StatisticsScreen), findsOneWidget);
  });

  testWidgets('tab fade: instant under reduced motion', (tester) async {
    await _pump(tester, reduced: true);
    await tester.tap(find.text('Stats'));
    await tester.pump();
    expect(_bodyFade(tester).opacity.value, 1);
    expect(find.byType(StatisticsScreen), findsOneWidget);
  });

  testWidgets('tapping the current tab does not fade', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Accueil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_bodyFade(tester).opacity.value, 1);
  });

  testWidgets('tab scroll and State survive switches', (tester) async {
    await _pump(tester);
    final stateBefore = tester.state(find.byType(HomeScreen));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    double offset() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    final before = offset();
    expect(before, greaterThan(0));

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();

    expect(
      identical(tester.state(find.byType(HomeScreen)), stateBefore),
      isTrue,
    );
    expect(offset(), before);
  });
}

/// Resets the override in `finally`: the binding checks it before tearDowns.
void androidTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
