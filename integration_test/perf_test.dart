// Profile-mode performance scenarios (F2): home_scroll, tab_switch,
// study_session, on a real device, with the real app widget, router, screens,
// repository and an in-memory Drift database (32 collections, 768 due cards,
// seed 42). Auth and sync are fakes. No network account, no Supabase init.
//
// !! WARNING: never point `flutter test` or a plain `flutter drive` at this file
// !! on a device holding the real app (`com.memflow.app.memflow`): Flutter builds
// !! under the real id, replaces the app, may uninstall it, and its encrypted
// !! local data can't be recovered. This happened once. The check in the test
// !! below runs too late to prevent it.
//
// Safe procedure, with `applicationId` changed to `com.memflow.app.memflow.perf`:
//   flutter build apk --profile -t integration_test/perf_test.dart \
//     --dart-define=PERF_LAYOUT=phone|tablet
//   aapt dump badging <apk> | head -1    # must show the .perf id
//   PERF_RUN=final_phone_1 ANDROID_SERIAL=<serial> flutter drive --profile \
//     --no-dds -d <serial> --use-application-binary=<apk> \
//     --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart
//
// --dart-define=PERF_BUILDS=true runs under debugProfileBuildsEnabled with a
// timeline (rebuild counts; timings perturbed, do not use them). Raw JSON goes to
// build/perf/$PERF_RUN.json. Phone layout = devicePixelRatio 3.2 (~412dp wide) on
// the same pixels: a simulation on tablet hardware, not a phone.
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:memflow/app/memflow_app.dart';
import 'package:memflow/app/providers.dart';
import 'package:memflow/data/local/database.dart';
import 'package:memflow/data/sync/sync_service.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _layout = String.fromEnvironment('PERF_LAYOUT', defaultValue: 'tablet');
const _builds = bool.fromEnvironment('PERF_BUILDS');

const _collections = 32, _decksPer = 2, _cardsPerDeck = 12; // 768 cards
const _sessionCards = 10;

class _FakeAuth implements AuthService {
  final _c = StreamController<AuthState>.broadcast();
  final _s = Session(
    accessToken: 't',
    tokenType: 'bearer',
    user: const User(
      id: 'u1',
      appMetadata: {},
      userMetadata: {'display_name': 'Perf'},
      aud: 'authenticated',
      createdAt: '2026-01-01',
    ),
  );
  @override
  Session? get currentSession => _s;
  @override
  User? get currentUser => _s.user;
  @override
  Stream<AuthState> get onAuthStateChange => _c.stream;
  void signIn() => _c.add(AuthState(AuthChangeEvent.signedIn, _s));
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeSync implements SyncService {
  static const _idle = SyncStatus(state: SyncState.idle, pendingCount: 0);
  @override
  Stream<SyncStatus> get statusStream => Stream.value(_idle);
  @override
  SyncStatus get status => _idle;
  @override
  Future<void> syncNow() async {}
  @override
  Future<void> startFor(String userId) async {}
  @override
  Future<void> stopAndClear() async {}
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _seed(AppDatabase db) async {
  final rng = Random(42);
  final now = DateTime.now();
  const modes = [TestMode.multipleChoice, TestMode.classicFlashcard];
  await db.batch((b) {
    for (var c = 0; c < _collections; c++) {
      final cid = 'c$c', cn = c.toString().padLeft(2, '0');
      b.insert(
        db.collections,
        CollectionsCompanion.insert(
          id: cid,
          name: 'Collection $cn',
          description: 'Collection de test numéro $cn',
          icon: '📚',
          color: 0xFF2F6F4F + rng.nextInt(0xFFFF),
          createdAt: now,
          updatedAt: now,
        ),
      );
      for (var d = 0; d < _decksPer; d++) {
        final did = 'c$c-d$d';
        b.insert(
          db.decks,
          DecksCompanion.insert(
            id: did,
            collectionId: cid,
            name: 'Deck $cn.$d',
            icon: '🗂️',
            difficulty: DeckDifficulty.values[rng.nextInt(4)],
            createdAt: now,
            updatedAt: now,
          ),
        );
        for (var k = 0; k < _cardsPerDeck; k++) {
          b.insert(
            db.flashcards,
            FlashcardsCompanion.insert(
              id: '$did-k$k',
              collectionId: cid,
              deckId: did,
              question: 'Question $cn.$d.$k ?',
              correctAnswer: 'Bonne réponse',
              wrongAnswers: [
                'Fausse un $k',
                'Fausse deux $k',
                'Fausse trois $k',
              ],
              explanation: Value('Explication de la carte $k : parce que.'),
              currentTestMode: TestMode.multipleChoice,
              allowedTestModes: modes,
              modeHistory: const [],
              clozeAnswers: const [],
              clozeWordBank: const [],
              acceptedAnswers: const [],
              level: 1 + rng.nextInt(4),
              tags: const [],
              dueAt: now.subtract(Duration(hours: 1 + rng.nextInt(120))),
              intervalDays: 1,
              easeFactor: 2.5,
              repetitions: rng.nextInt(5),
              lapses: 0,
              mastered: false,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }
    }
  });
}

// The home list is lazy and its order isn't by name: match any visible row.
final _anyCollection = find.textContaining(RegExp(r'^Collection \d\d$'));

/// pumpAndSettle can return before a database stream emits: wait on content.
Future<void> _until(
  WidgetTester tester,
  bool Function() done,
  String what,
) async {
  for (var i = 0; i < 300; i++) {
    if (done()) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  final shown = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .take(25);
  fail('Timed out waiting for $what. On screen: $shown');
}

Future<void> _waitFor(WidgetTester tester, Finder f) => _until(
  tester,
  () => f.evaluate().isNotEmpty,
  f.describeMatch(Plurality.many),
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> measure(String key, Future<void> Function() action) async {
    if (_builds) {
      debugProfileBuildsEnabled = true;
      await binding.traceAction(
        action,
        streams: const ['Dart'],
        reportKey: key,
      );
      debugProfileBuildsEnabled = false;
    } else {
      await binding.watchPerformance(action, reportKey: key);
    }
  }

  testWidgets('perf', (tester) async {
    if (Platform.isAndroid) {
      final cmd = File('/proc/self/cmdline').readAsStringSync();
      if (!cmd.contains('.perf')) {
        fail('Refusing to run: process "$cmd" is not a .perf application id.');
      }
    }
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    if (_layout == 'phone') tester.view.devicePixelRatio = 3.2;
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'session_card_limit': _sessionCards,
      'theme_preference': 'light', // ignored by the final version
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    await _seed(db);
    final auth = _FakeAuth();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authServiceProvider.overrideWithValue(auth),
          appDatabaseProvider.overrideWithValue(db),
          syncServiceProvider.overrideWithValue(_FakeSync()),
        ],
        child: const MemFlowApp(),
      ),
    );
    auth.signIn();
    await _waitFor(tester, find.textContaining('cartes à revoir'));
    await tester.pumpAndSettle();

    final vertical = find
        .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
        .first;
    Future<void> scrollHome() async {
      for (var r = 0; r < 3; r++) {
        for (var i = 0; i < 3; i++) {
          await tester.fling(vertical, const Offset(0, -700), 2500);
          await tester.pumpAndSettle();
        }
        for (var i = 0; i < 3; i++) {
          await tester.fling(vertical, const Offset(0, 700), 2500);
          await tester.pumpAndSettle();
        }
      }
    }

    Future<void> tab(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> switchTabs() async {
      for (var r = 0; r < 5; r++) {
        for (final l in ['Stats', 'Importer', 'Profil', 'Accueil']) {
          await tab(l);
        }
      }
    }

    // Warm-up, not measured.
    await scrollHome();
    await switchTabs();
    await tester.pump(const Duration(seconds: 2));

    await measure('home_scroll', scrollHome);
    await measure('tab_switch', switchTabs);

    final row = _anyCollection.hitTestable();

    Future<void> study() async {
      await tester.tap(row.first);
      await _waitFor(tester, find.text('Étudier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Étudier'));
      await _waitFor(tester, find.text('QCM'));
      // Fixed wait: the baseline's spinner behind the sheet never settles.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.ensureVisible(find.text('QCM'));
      await tester.tap(find.text('QCM'));
      final rated = find.text('Correct'), done = find.text('Session terminée');
      for (var i = 0; i < _sessionCards; i++) {
        final ok = find.text('Bonne réponse');
        await _waitFor(tester, ok);
        await tester.pumpAndSettle();
        await tester.ensureVisible(ok.first);
        await tester.tap(ok.first);
        await _waitFor(tester, rated);
        await tester.pumpAndSettle();
        await tester.ensureVisible(rated.last);
        await tester.tap(rated.last);
        // The next card or the summary replaces the rating buttons.
        await _until(
          tester,
          () => rated.evaluate().isEmpty || done.evaluate().isNotEmpty,
          'the next card',
        );
      }
      await _waitFor(tester, done);
      await tester.pumpAndSettle();
    }

    // Not measured: bring a tappable collection row on screen.
    for (var i = 0; i < 40 && row.evaluate().isEmpty; i++) {
      await tester.drag(vertical, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();
    await measure('study_session', study);
    await tester.pump(const Duration(seconds: 1));
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    binding.reportData = {
      ...?binding.reportData,
      'meta': {
        'layout': _layout,
        'builds': _builds,
        'logical_size': '${size.width.round()}x${size.height.round()}',
        'cards': _collections * _decksPer * _cardsPerDeck,
        'mode': kProfileMode ? 'profile' : (kReleaseMode ? 'release' : 'debug'),
      },
    };
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 15)));
}
