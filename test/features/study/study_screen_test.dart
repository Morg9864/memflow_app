import 'dart:async';
import 'dart:math' as math;

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
  StudyCard buildCard(String id) {
    return StudyCard(
      id: id,
      collectionId: 'react',
      deckId: 'deck-1',
      question: 'Question $id',
      correctAnswer: 'Réponse $id',
      wrongAnswers: const ['A', 'B', 'C'],
      hint: null,
      explanation: null,
      currentTestMode: TestMode.multipleChoice,
      allowedTestModes: const [TestMode.multipleChoice],
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

  StudySessionState buildState(List<StudyCard> cards) {
    return StudySessionState(
      deckTitle: 'React',
      collectionId: 'react',
      deckId: 'deck-1',
      cards: cards,
      sessionCardIds: cards.map((card) => card.id).toSet(),
      seenCardIds: const <String>{},
      pendingReviewResults: const <String, ReviewResult>{},
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

  Future<void> pumpStudyScreen(
    WidgetTester tester, {
    required StudyController controller,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
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
