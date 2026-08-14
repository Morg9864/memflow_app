import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/app/app_scaffold_messenger.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/features/study/study_controller.dart';
import 'package:memflow/features/study/study_screen.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:memflow/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  StudyCard buildCard(
    String id, {
    TestMode mode = TestMode.multipleChoice,
    String? explanation,
  }) {
    return StudyCard(
      id: id,
      collectionId: 'react',
      deckId: 'deck-1',
      question: 'Question $id',
      correctAnswer: 'Réponse $id',
      wrongAnswers: const ['A', 'B', 'C'],
      hint: null,
      explanation: explanation,
      currentTestMode: mode,
      allowedTestModes: [mode],
      clozeText: null,
      clozeAnswers: const [],
      clozeWordBank: const [],
      acceptedAnswers: const [],
      level: 1,
      progressDots: 3,
    );
  }

  StudyCard buildClozeCard() {
    return StudyCard(
      id: 'cloze',
      collectionId: 'react',
      deckId: 'deck-1',
      question:
          'Quel hook React retourne une valeur et une fonction de mise à jour ?',
      correctAnswer: 'useState',
      wrongAnswers: const ['useEffect', 'useMemo', 'useRef'],
      hint: null,
      explanation:
          'useState retourne une valeur actuelle et une fonction pour la modifier.',
      currentTestMode: TestMode.cloze,
      allowedTestModes: const [TestMode.cloze],
      clozeText:
          'React, le hook {{useState}} retourne une valeur actuelle et une fonction pour la {{modifier}}.',
      clozeAnswers: const ['useState', 'modifier'],
      clozeWordBank: const ['useState', 'useEffect', 'afficher', 'modifier'],
      acceptedAnswers: const [],
      level: 1,
      progressDots: 3,
    );
  }

  StudySessionState buildState(
    List<StudyCard> cards, {
    bool revealed = false,
    bool hasValidatedAnswer = false,
    bool? currentAnswerWasCorrect,
  }) {
    return StudySessionState(
      deckTitle: 'React',
      collectionId: 'react',
      deckId: 'deck-1',
      cards: cards,
      currentIndex: 0,
      revealed: revealed,
      selectedOptionIndex: null,
      hasValidatedAnswer: hasValidatedAnswer,
      freeTextAnswer: '',
      reviewCounts: const {
        ReviewResult.again: 0,
        ReviewResult.hard: 0,
        ReviewResult.good: 0,
        ReviewResult.easy: 0,
      },
      currentAnswerWasCorrect: currentAnswerWasCorrect,
      isCompleted: false,
    );
  }

  Future<void> pumpStudyScreen(
    WidgetTester tester, {
    required StudyController controller,
    Size size = const Size(1200, 1600),
    TargetPlatform? platform,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      debugDefaultTargetPlatformOverride = null;
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          scaffoldMessengerKey: appScaffoldMessengerKey,
          theme: AppTheme.light(),
          home: StudyScreen(
            collectionId: 'react',
            deckId: 'deck-1',
            forcedMode: TestMode.multipleChoice,
            controller: controller,
          ),
        ),
      ),
    );

    await tester.pump();
  }

  testWidgets(
    'selecting a review advances immediately to the next card before save completes',
    (tester) async {
      final pendingSave = Completer<void>();
      final controller = _FakeStudyController(
        initialState: buildState([buildCard('a'), buildCard('b')]),
        submitReviewImpl:
            ({
              required String cardId,
              required ReviewResult result,
              required bool wasCorrect,
            }) {
              return pendingSave.future;
            },
      );

      await pumpStudyScreen(tester, controller: controller);

      expect(find.text('Question a'), findsOneWidget);

      await tester.tap(find.text('Réponse a'));
      await tester.pump();
      await tester.tap(find.text('Correct'));
      await tester.pump();

      expect(find.text('Question b'), findsOneWidget);
      expect(controller.submissions.length, 1);

      pendingSave.complete();
    },
  );

  testWidgets(
    'a failed save shows a retry snackbar without rewinding the session',
    (tester) async {
      var attempts = 0;
      final controller = _FakeStudyController(
        initialState: buildState([buildCard('a'), buildCard('b')]),
        submitReviewImpl:
            ({
              required String cardId,
              required ReviewResult result,
              required bool wasCorrect,
            }) async {
              attempts += 1;
              if (attempts == 1) {
                throw Exception('network');
              }
            },
      );

      await pumpStudyScreen(tester, controller: controller);

      await tester.tap(find.text('Réponse a'));
      await tester.pump();
      await tester.tap(find.text('Correct'));
      await tester.pump();

      expect(find.text('Question b'), findsOneWidget);

      await tester.pump();

      expect(
        find.text(
          'La carte suivante est déjà prête, mais une sauvegarde a échoué.',
        ),
        findsOneWidget,
      );
      expect(find.text('Réessayer'), findsOneWidget);

      final retryAction = tester.widget<SnackBarAction>(
        find.byType(SnackBarAction),
      );
      retryAction.onPressed();
      await tester.pump();

      expect(attempts, 2);
      expect(controller.submissions.length, 2);
    },
  );

  testWidgets(
    'structured cloze mode fills blanks from the word bank and validates the full text',
    (tester) async {
      final controller = _FakeStudyController(
        initialState: buildState([buildClozeCard()]),
        submitReviewImpl:
            ({
              required String cardId,
              required ReviewResult result,
              required bool wasCorrect,
            }) async {},
      );

      await pumpStudyScreen(tester, controller: controller);

      expect(find.text('useEffect'), findsOneWidget);
      expect(find.text('afficher'), findsOneWidget);

      await tester.tap(find.text('_____').first);
      await tester.pump();
      await tester.tap(find.text('useState'));
      await tester.pump();

      await tester.tap(find.text('_____').first);
      await tester.pump();
      await tester.tap(find.text('modifier'));
      await tester.pump();

      await tester.tap(find.text('Valider ma réponse'));
      await tester.pump();

      expect(
        find.text(
          'React, le hook useState retourne une valeur actuelle et une fonction pour la modifier.',
        ),
        findsOneWidget,
      );
      expect(find.text('useEffect'), findsWidgets);
    },
  );

  testWidgets(
    'wide desktop moves correction and review controls into a right panel',
    (tester) async {
      final controller = _FakeStudyController(
        initialState: buildState([buildCard('desktop')]),
        submitReviewImpl:
            ({
              required String cardId,
              required ReviewResult result,
              required bool wasCorrect,
            }) async {},
      );

      await pumpStudyScreen(
        tester,
        controller: controller,
        size: const Size(1366, 768),
        platform: TargetPlatform.linux,
      );

      expect(find.byKey(const Key('desktop-review-panel')), findsNothing);

      await tester.tap(find.text('Réponse desktop'));
      await tester.pumpAndSettle();

      final panel = find.byKey(const Key('desktop-review-panel'));
      expect(panel, findsOneWidget);
      expect(find.byKey(const Key('inline-review-controls')), findsNothing);
      expect(tester.getTopLeft(panel).dx, greaterThan(900));
      expect(find.text('COMMENT TU T’EN ES SORTI ?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('tablet layout keeps the existing inline review controls', (
    tester,
  ) async {
    final controller = _FakeStudyController(
      initialState: buildState([buildCard('tablet')]),
      submitReviewImpl:
          ({
            required String cardId,
            required ReviewResult result,
            required bool wasCorrect,
          }) async {},
    );

    await pumpStudyScreen(
      tester,
      controller: controller,
      size: const Size(1200, 900),
      platform: TargetPlatform.android,
    );

    await tester.tap(find.text('Réponse tablet'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-review-panel')), findsNothing);
    expect(find.byKey(const Key('inline-review-controls')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  final desktopModeCases = <({TestMode mode, String expectedAnswer})>[
    (mode: TestMode.multipleChoice, expectedAnswer: 'Réponse mode-mcq'),
    (mode: TestMode.trueFalse, expectedAnswer: 'Réponse mode-true-false'),
    (mode: TestMode.freeText, expectedAnswer: 'Réponse mode-free-text'),
    (mode: TestMode.classicFlashcard, expectedAnswer: 'Réponse mode-flash'),
    (
      mode: TestMode.reversedFlashcard,
      expectedAnswer: 'Question mode-reversed',
    ),
  ];

  for (final testCase in desktopModeCases) {
    testWidgets(
      'desktop review panel presents feedback for ${testCase.mode.name}',
      (tester) async {
        final card = buildCard(
          'mode-${switch (testCase.mode) {
            TestMode.multipleChoice => 'mcq',
            TestMode.trueFalse => 'true-false',
            TestMode.freeText => 'free-text',
            TestMode.classicFlashcard => 'flash',
            TestMode.reversedFlashcard => 'reversed',
            _ => 'other',
          }}',
          mode: testCase.mode,
          explanation: 'Une explication suffisamment claire.',
        );
        final isFlashcard =
            testCase.mode == TestMode.classicFlashcard ||
            testCase.mode == TestMode.reversedFlashcard;
        final controller = _FakeStudyController(
          initialState: buildState(
            [card],
            revealed: isFlashcard,
            hasValidatedAnswer: !isFlashcard,
            currentAnswerWasCorrect: isFlashcard ? null : false,
          ),
          submitReviewImpl:
              ({
                required String cardId,
                required ReviewResult result,
                required bool wasCorrect,
              }) async {},
        );

        await pumpStudyScreen(
          tester,
          controller: controller,
          size: const Size(1366, 768),
          platform: TargetPlatform.linux,
        );

        final panel = find.byKey(const Key('desktop-review-panel'));
        expect(panel, findsOneWidget);
        expect(
          find.descendant(
            of: panel,
            matching: find.text(testCase.expectedAnswer),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: panel,
            matching: find.text('Une explication suffisamment claire.'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('desktop review panel presents cloze solution', (tester) async {
    final card = buildClozeCard();
    final controller = _FakeStudyController(
      initialState: buildState(
        [card],
        hasValidatedAnswer: true,
        currentAnswerWasCorrect: true,
      ),
      submitReviewImpl:
          ({
            required String cardId,
            required ReviewResult result,
            required bool wasCorrect,
          }) async {},
    );

    await pumpStudyScreen(
      tester,
      controller: controller,
      size: const Size(1366, 768),
      platform: TargetPlatform.linux,
    );

    final panel = find.byKey(const Key('desktop-review-panel'));
    expect(panel, findsOneWidget);
    expect(
      find.descendant(
        of: panel,
        matching: find.text(
          'React, le hook useState retourne une valeur actuelle et une fonction pour la modifier.',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}

typedef _SubmitReviewCallback =
    Future<void> Function({
      required String cardId,
      required ReviewResult result,
      required bool wasCorrect,
    });

class _FakeStudyController extends StudyController {
  _FakeStudyController({
    required StudySessionState initialState,
    required _SubmitReviewCallback submitReviewImpl,
  }) : _initialState = initialState,
       _submitReviewImpl = submitReviewImpl,
       super.forTesting(random: math.Random(0));

  final StudySessionState _initialState;
  final _SubmitReviewCallback _submitReviewImpl;
  final List<({String cardId, ReviewResult result, bool wasCorrect})>
  submissions = [];

  @override
  Future<StudySessionState> load({
    String? collectionId,
    String? deckId,
    TestMode? forcedMode,
    required int sessionCardLimit,
  }) async {
    return _initialState;
  }

  @override
  Future<void> submitReview({
    required String cardId,
    required ReviewResult result,
    required bool wasCorrect,
  }) {
    submissions.add((cardId: cardId, result: result, wasCorrect: wasCorrect));
    return _submitReviewImpl(
      cardId: cardId,
      result: result,
      wasCorrect: wasCorrect,
    );
  }
}
