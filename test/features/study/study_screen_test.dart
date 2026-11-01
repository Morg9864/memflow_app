import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/app/app_scaffold_messenger.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/features/study/study_controller.dart';
import 'package:memflow/features/study/study_screen.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:memflow/app/providers.dart';
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
          builder: (context, child) => AdaptiveTheme(child: child!),
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

  testWidgets('a review is not advanced before local save completes', (
    tester,
  ) async {
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

    expect(find.text('Question a'), findsWidgets);

    await tester.tap(find.text('Réponse a'));
    await tester.pump();
    await tester.tap(find.text('Correct'));
    await tester.pump();

    expect(find.text('Question a'), findsWidgets);
    expect(controller.submissions.length, 1);

    pendingSave.complete();
    await tester.pump();
    expect(find.text('Question b'), findsOneWidget);
  });

  testWidgets('a failed save keeps the current card visible', (tester) async {
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

    expect(find.text('Question a'), findsWidgets);

    await tester.pump();

    expect(
      find.text('La sauvegarde locale a échoué. Réessaie.'),
      findsOneWidget,
    );
    expect(attempts, 1);
    expect(controller.submissions.length, 1);
  });

  testWidgets('number shortcuts submit the selected review immediately', (
    tester,
  ) async {
    final controller = _FakeStudyController(
      initialState: buildState([buildCard('a'), buildCard('b')]),
      submitReviewImpl:
          ({
            required String cardId,
            required ReviewResult result,
            required bool wasCorrect,
          }) async {},
    );

    await pumpStudyScreen(tester, controller: controller);

    await tester.tap(find.text('Réponse a'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump();

    expect(find.text('Question b'), findsOneWidget);
    expect(controller.submissions.single.result, ReviewResult.good);
  });

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

  testWidgets(
    'wide Android window gets the side panel, without keyboard hint',
    (tester) async {
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

      expect(find.byKey(const Key('desktop-review-panel')), findsOneWidget);
      expect(find.byKey(const Key('inline-review-controls')), findsNothing);
      expect(find.textContaining('Clavier :'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  // Cartes aux réponses distinctives (les pastilles A-D ne s'y confondent pas).
  StudyCard buildChoiceCard(String id, {String? explanation}) => StudyCard(
    id: id,
    collectionId: 'react',
    deckId: 'deck-1',
    question: 'Question $id',
    correctAnswer: 'Bonne $id',
    wrongAnswers: const ['Faux un', 'Faux deux', 'Faux trois'],
    hint: null,
    explanation: explanation,
    currentTestMode: TestMode.multipleChoice,
    allowedTestModes: const [TestMode.multipleChoice],
    clozeText: null,
    clozeAnswers: const [],
    clozeWordBank: const [],
    acceptedAnswers: const [],
    level: 1,
  );

  _FakeStudyController fakeController(List<StudyCard> cards) =>
      _FakeStudyController(
        initialState: buildState(cards),
        submitReviewImpl:
            ({
              required String cardId,
              required ReviewResult result,
              required bool wasCorrect,
            }) async {},
      );

  Offset topLeftOf(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text));

  Size tileSize(WidgetTester tester, String text) => tester.getSize(
    find.ancestor(of: find.text(text), matching: find.byType(InkWell)).first,
  );

  testWidgets('portrait Android tablet: 2x2 answers, one rating row', (
    tester,
  ) async {
    await pumpStudyScreen(
      tester,
      controller: fakeController([buildChoiceCard('a')]),
      size: const Size(880, 1408),
      platform: TargetPlatform.android,
    );
    final texts = ['Bonne a', 'Faux un', 'Faux deux', 'Faux trois'];
    final positions = [for (final t in texts) topLeftOf(tester, t)]
      ..sort(
        (p, q) => p.dy != q.dy ? p.dy.compareTo(q.dy) : p.dx.compareTo(q.dx),
      );
    expect(positions[0].dy, positions[1].dy);
    expect(positions[2].dy, positions[3].dy);
    expect(positions[2].dy, greaterThan(positions[0].dy));
    expect(positions[1].dx, greaterThan(positions[0].dx));
    expect(positions[2].dx, positions[0].dx);
    // La pastille de lettre est un carré fixe, pas un bloc étiré à la tuile.
    final badge = tester.getSize(
      find
          .ancestor(of: find.text('A'), matching: find.byType(DecoratedBox))
          .first,
    );
    expect(badge, const Size(40, 40));
    final sizes = {for (final t in texts) tileSize(tester, t)};
    expect(sizes.length, 1);
    expect(sizes.first.height, greaterThanOrEqualTo(88));

    await tester.tap(find.text('Bonne a'));
    await tester.pumpAndSettle();
    final rows = {
      for (final t in ['Encore', 'Difficile', 'Correct', 'Facile'])
        topLeftOf(tester, t).dy,
    };
    expect(rows.length, 1);
    expect(find.textContaining('Clavier :'), findsNothing);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('portrait Android tablet: true/false answers sit side by side', (
    tester,
  ) async {
    final controller = fakeController([
      buildCard('tf', mode: TestMode.trueFalse),
    ]);
    await pumpStudyScreen(
      tester,
      controller: controller,
      size: const Size(880, 1408),
      platform: TargetPlatform.android,
    );
    final vrai = topLeftOf(tester, 'Vrai');
    final faux = topLeftOf(tester, 'Faux');
    expect(vrai.dy, faux.dy);
    expect(faux.dx, greaterThan(vrai.dx));
    expect(tileSize(tester, 'Vrai'), tileSize(tester, 'Faux'));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('phone width keeps answers in a single column', (tester) async {
    await pumpStudyScreen(
      tester,
      controller: fakeController([buildChoiceCard('a')]),
      size: const Size(360, 800),
      platform: TargetPlatform.android,
    );
    final positions = [
      for (final t in ['Bonne a', 'Faux un', 'Faux deux', 'Faux trois'])
        topLeftOf(tester, t),
    ]..sort((p, q) => p.dy.compareTo(q.dy));
    expect({for (final p in positions) p.dx}.length, 1);
    expect({for (final p in positions) p.dy}.length, 4);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'landscape Android tablet gets the side panel, no keyboard hint',
    (tester) async {
      final controller = _FakeStudyController(
        initialState: buildState([buildChoiceCard('a')]),
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
        size: const Size(1408, 880),
        platform: TargetPlatform.android,
      );
      await tester.tap(find.text('Bonne a'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('desktop-review-panel')), findsOneWidget);
      expect(find.textContaining('Clavier :'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('a stylus answers, rates and moves to the next card', (
    tester,
  ) async {
    final controller = fakeController([
      buildChoiceCard('a'),
      buildChoiceCard('b'),
    ]);
    await pumpStudyScreen(
      tester,
      controller: controller,
      size: const Size(880, 1408),
      platform: TargetPlatform.android,
    );
    final pen = await tester.createGesture(kind: PointerDeviceKind.stylus);
    Future<void> penTap(Finder finder) async {
      await pen.down(tester.getCenter(finder));
      await pen.up();
      await tester.pumpAndSettle();
    }

    await penTap(find.text('Bonne a'));
    await penTap(find.text('Correct'));
    expect(controller.submissions.single.result, ReviewResult.good);
    expect(find.text('Question b'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a stylus drag scrolls overflowing content', (tester) async {
    final controller = _FakeStudyController(
      initialState: buildState(
        [buildChoiceCard('a', explanation: 'Longue explication. ' * 60)],
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
      size: const Size(880, 500),
      platform: TargetPlatform.android,
    );
    final scrollable = find
        .descendant(
          of: find.byKey(const Key('desktop-study-content')),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
    final pen = await tester.createGesture(kind: PointerDeviceKind.stylus);
    await pen.down(const Offset(440, 350));
    await pen.moveBy(const Offset(0, -150));
    await pen.moveBy(const Offset(0, -150));
    await pen.up();
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('rotating mid-session keeps the typed text and the card', (
    tester,
  ) async {
    final controller = fakeController([
      buildCard('a', mode: TestMode.freeText),
      buildCard('b', mode: TestMode.freeText),
    ]);
    await pumpStudyScreen(
      tester,
      controller: controller,
      size: const Size(880, 1408),
      platform: TargetPlatform.android,
    );
    await tester.enterText(find.byType(TextField), 'ma réponse');
    tester.view.physicalSize = const Size(1408, 880);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(880, 1408);
    await tester.pumpAndSettle();
    expect(find.text('ma réponse'), findsOneWidget);
    expect(find.text('Question a'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('open keyboard on a free-text card: no overflow, field visible', (
    tester,
  ) async {
    await pumpStudyScreen(
      tester,
      controller: fakeController([buildCard('a', mode: TestMode.freeText)]),
      size: const Size(880, 1408),
      platform: TargetPlatform.android,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 420);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byType(TextField));
    expect(field.top, greaterThanOrEqualTo(0));
    expect(field.bottom, lessThanOrEqualTo(1408 - 420));
    // Clavier ouvert, la carte abandonne sa hauteur minimale.
    final card = find.ancestor(
      of: find.byType(TextField),
      matching: find.byType(Card),
    );
    expect(tester.getSize(card.first).height, lessThan(1408 * 0.25));
    expect(tester.takeException(), isNull);
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
       super.fromPersistence(
         random: math.Random(0),
         loadSession:
             ({
               collectionId,
               deckId,
               forcedMode,
               required sessionCardLimit,
             }) async => initialState,
         submitReview:
             ({
               required cardId,
               required reviewResult,
               required wasCorrect,
               required playedMode,
             }) async {},
       );

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
    required TestMode playedMode,
  }) {
    submissions.add((cardId: cardId, result: result, wasCorrect: wasCorrect));
    return _submitReviewImpl(
      cardId: cardId,
      result: result,
      wasCorrect: wasCorrect,
    );
  }

  @override
  Future<void> submitReviewIdempotent({
    required String reviewId,
    required String cardId,
    required ReviewResult result,
    required bool wasCorrect,
    required TestMode playedMode,
  }) => submitReview(
    cardId: cardId,
    result: result,
    wasCorrect: wasCorrect,
    playedMode: playedMode,
  );
}
