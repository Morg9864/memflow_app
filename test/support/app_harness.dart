// The real router and real screens, with a fake repository and fake auth.
// Used by test/journeys/*.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/app/providers.dart';
import 'package:memflow/app/router.dart';
import 'package:memflow/data/repositories/app_repository.dart';
import 'package:memflow/data/sync/sync_service.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/auth_service.dart';
import 'package:memflow/domain/services/card_mode_service.dart';
import 'package:memflow/features/home/home_screen.dart';
import 'package:memflow/features/collections/collection_detail_screen.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screen_cases.dart' show fixtureCollection;

const testUser = User(
  id: 'u1',
  appMetadata: {},
  userMetadata: {
    'display_name': 'Léa',
    'adult_attested_at': '2026-11-02T00:00:00Z',
    'accepted_terms_version': '2026-11-02',
  },
  aud: 'authenticated',
  createdAt: '2026-01-01',
);

class FakeAuth implements AuthService {
  final _controller = StreamController<AuthState>.broadcast();
  Session? session = Session(
    accessToken: 't',
    tokenType: 'bearer',
    user: testUser,
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
  Future<void> signOut() async {
    session = null;
    emit(AuthChangeEvent.signedOut);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A two-card QCM session. Every write is appended to [log] in call order;
/// [submitGate], when set, holds the review write until it completes.
class FakeRepository implements AppRepository {
  final log = <String>[];
  Completer<void>? submitGate;

  @override
  Future<StudyModeAvailability> studyModeAvailability({
    String? collectionId,
    String? deckId,
  }) async => const StudyModeAvailability(
    total: 2,
    compatible: {TestMode.multipleChoice: 2, TestMode.classicFlashcard: 2},
  );

  @override
  Future<StudySessionState> startStudySession({
    String? collectionId,
    String? deckId,
    TestMode? forcedMode,
    Set<String>? onlyCardIds,
    required int sessionCardLimit,
  }) async {
    log.add('start:${forcedMode?.name}');
    StudyCard card(String id) => StudyCard(
      id: id,
      collectionId: 'c1',
      deckId: 'd0',
      question: 'Question $id ?',
      correctAnswer: 'Bonne réponse',
      wrongAnswers: const ['Fausse un', 'Fausse deux', 'Fausse trois'],
      hint: null,
      clozeText: null,
      explanation: 'Parce que.',
      currentTestMode: TestMode.multipleChoice,
      allowedTestModes: const [TestMode.multipleChoice],
      clozeAnswers: const [],
      clozeWordBank: const [],
      acceptedAnswers: const [],
      level: 1,
    );
    return StudySessionState(
      deckTitle: 'Biologie',
      collectionId: 'c1',
      deckId: 'd0',
      cards: [card('a'), card('b')],
      currentIndex: 0,
      revealed: false,
      selectedOptionIndex: null,
      hasValidatedAnswer: false,
      freeTextAnswer: '',
      reviewCounts: const {
        ReviewResult.again: 0,
        ReviewResult.hard: 0,
        ReviewResult.good: 0,
        ReviewResult.easy: 0,
      },
      currentAnswerWasCorrect: null,
      isCompleted: false,
    );
  }

  @override
  Future<void> submitReview({
    String? reviewId,
    required String cardId,
    required ReviewResult reviewResult,
    required bool wasCorrect,
    required TestMode playedMode,
  }) async {
    log.add('submit:$cardId:${reviewResult.name}');
    await submitGate?.future;
    log.add('submitted:$cardId');
  }

  @override
  Future<void> saveStudySession(StudySessionState state) async =>
      log.add('save:${state.currentIndex}');

  // Not under test here.
  @override
  Stream<int> watchDueCardsForCollectionRevision() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Boots the whole app on [FakeAuth] (signed in) and [repo], at 360x800.
Future<(GoRouter, FakeAuth)> pumpApp(
  WidgetTester tester,
  FakeRepository repo, {
  FakeAuth? auth,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fakeAuth = auth ?? FakeAuth();
  final biology = fixtureCollection('c1', 'Biologie');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(fakeAuth),
        currentUserProvider.overrideWithValue(testUser),
        appRepositoryProvider.overrideWithValue(repo),
        homeStatsProvider.overrideWith(
          (ref) => Stream.value(
            const HomeStats(
              streakDays: 3,
              successRate: .8,
              dueCards: 5,
              totalCardsSeen: 20,
            ),
          ),
        ),
        homeCollectionsProvider.overrideWith(
          (ref, s) => Stream.value([biology]),
        ),
        collectionProvider.overrideWith((ref, id) => Stream.value(biology)),
        collectionDecksProvider.overrideWith(
          (ref, id) => Stream.value(const <DeckListItem>[]),
        ),
        syncStatusProvider.overrideWith(
          (ref) => Stream.value(
            const SyncStatus(state: SyncState.idle, pendingCount: 0),
          ),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: ref.watch(routerProvider),
          builder: (context, child) => AdaptiveTheme(child: child!),
        ),
      ),
    ),
  );
  fakeAuth.emit(AuthChangeEvent.signedIn);
  await tester.pumpAndSettle();
  final router = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  ).read(routerProvider);
  return (router, fakeAuth);
}

/// Home -> collection detail -> "Étudier" (mode sheet opens).
Future<void> openModeSheetFromHome(WidgetTester tester) async {
  await tester.tap(find.text('Biologie'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Étudier'));
  await tester.pumpAndSettle();
}
