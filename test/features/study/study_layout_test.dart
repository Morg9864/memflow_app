import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/app/app_scaffold_messenger.dart';
import 'package:memflow/app/providers.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/features/study/study_controller.dart';
import 'package:memflow/features/study/study_screen.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _long =
    'Une question volontairement très longue qui décrit en détail le '
    'mécanisme de réplication semi-conservative de l’ADN chez les '
    'eucaryotes, avec toutes les enzymes impliquées, leur ordre '
    'd’intervention, leurs cofacteurs, et les points de contrôle du cycle '
    'cellulaire qui garantissent la fidélité de la copie du génome.';

typedef _Viewport = ({String name, Size size, double textScale});

const _viewports = <_Viewport>[
  (name: '320x568', size: Size(320, 568), textScale: 1.0),
  (name: '360x800', size: Size(360, 800), textScale: 1.0),
  (name: '360x800 @2.0', size: Size(360, 800), textScale: 2.0),
];

StudyCard _card(String id, TestMode mode, {String? question, String? hint}) {
  final isCloze = mode == TestMode.cloze;
  return StudyCard(
    id: id,
    collectionId: 'bio',
    deckId: 'deck-1',
    question: '$id ${question ?? _long}',
    correctAnswer: isCloze ? 'réplication' : 'Bonne réponse longue $id',
    wrongAnswers: [
      'Mauvaise réponse très longue numéro un $id $_long',
      'Mauvaise réponse très longue numéro deux $id $_long',
      'Mauvaise réponse très longue numéro trois $id $_long',
    ],
    hint: hint ?? 'Indice : pense à la fourche de réplication et aux brins.',
    explanation: 'Explication détaillée. $_long',
    currentTestMode: mode,
    allowedTestModes: [mode],
    clozeText: isCloze
        ? 'La {{réplication}} est semi-conservative et fait intervenir une '
              '{{hélicase}} puis une polymérase. $_long'
        : null,
    clozeAnswers: isCloze ? const ['réplication', 'hélicase'] : const [],
    clozeWordBank: isCloze
        ? const [
            'réplication',
            'hélicase',
            'transcription',
            'ribosome',
            'mitochondrie',
            'glycolyse',
            'cytoplasme',
            'chromatine',
          ]
        : const [],
    acceptedAnswers: const [],
    level: 2,
  );
}

StudySessionState _state(List<StudyCard> cards, {bool revealed = false}) {
  return StudySessionState(
    deckTitle:
        'Un titre de deck vraiment très long pour vérifier la coupe sur '
        'deux lignes maximum dans l’en-tête de session',
    collectionId: 'bio',
    deckId: 'deck-1',
    cards: cards,
    currentIndex: 0,
    revealed: revealed,
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

Future<_FakeStudyController> _pump(
  WidgetTester tester, {
  required List<StudyCard> cards,
  required Size size,
  double textScale = 1.0,
  double keyboard = 0,
  bool reduceMotion = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  });
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = _FakeStudyController(initialState: _state(cards));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        scaffoldMessengerKey: appScaffoldMessengerKey,
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: StudyScreen(
          collectionId: 'bio',
          deckId: 'deck-1',
          forcedMode: cards.first.currentTestMode,
          controller: controller,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return controller;
}

/// Scrolls the finder into view, then asserts it is inside the visible area
/// (above the keyboard) before tapping it.
Future<void> _reachAndTap(
  WidgetTester tester,
  Finder finder, {
  double keyboard = 0,
}) async {
  expect(finder, findsWidgets);
  final target = finder.first;
  await tester.ensureVisible(target);
  await tester.pump();
  final rect = tester.getRect(target);
  final view = tester.view.physicalSize;
  expect(rect.top, greaterThanOrEqualTo(-0.5), reason: '$finder above screen');
  expect(
    rect.bottom,
    lessThanOrEqualTo(view.height - keyboard + 0.5),
    reason: '$finder below visible area',
  );
  await tester.tap(target);
  await tester.pump();
}

Finder _lastOption(WidgetTester tester) {
  final finders = [
    find.textContaining('Bonne réponse longue'),
    find.textContaining('Mauvaise réponse très longue numéro un'),
    find.textContaining('Mauvaise réponse très longue numéro deux'),
    find.textContaining('Mauvaise réponse très longue numéro trois'),
  ];
  finders.sort(
    (a, b) =>
        tester.getTopLeft(a.first).dy.compareTo(tester.getTopLeft(b.first).dy),
  );
  return finders.last;
}

Future<void> _answer(WidgetTester tester, TestMode mode) async {
  switch (mode) {
    case TestMode.multipleChoice:
      await _reachAndTap(tester, _lastOption(tester));
    case TestMode.trueFalse:
      await _reachAndTap(tester, find.text('Faux'));
    case TestMode.freeText:
      await tester.enterText(find.byType(TextField), 'ma réponse');
      await tester.pump();
      await _reachAndTap(tester, find.text('Vérifier'));
    case TestMode.cloze:
      await _reachAndTap(tester, find.text('_____').first);
      await _reachAndTap(tester, find.text('réplication'));
      await _reachAndTap(tester, find.text('_____').first);
      await _reachAndTap(tester, find.text('hélicase'));
      await _reachAndTap(tester, find.text('Valider ma réponse'));
    default:
      await _reachAndTap(tester, find.text('Révéler la réponse'));
  }
}

const _modes = <TestMode>[
  TestMode.multipleChoice,
  TestMode.classicFlashcard,
  TestMode.reversedFlashcard,
  TestMode.freeText,
  TestMode.trueFalse,
  TestMode.cloze,
];

void main() {
  for (final mode in _modes) {
    for (final viewport in _viewports) {
      testWidgets(
        '${mode.name} at ${viewport.name} has reachable controls and no overflow',
        (tester) async {
          final controller = await _pump(
            tester,
            cards: [_card('a', mode), _card('b', mode)],
            size: viewport.size,
            textScale: viewport.textScale,
          );
          expect(tester.takeException(), isNull, reason: 'before answer');

          await _answer(tester, mode);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'after answer');

          for (final label in ['Encore', 'Difficile', 'Correct', 'Facile']) {
            await _reachAndTap(tester, find.text(label).first).then((_) {});
            // The first tap already applied the review; only check the first.
            break;
          }
          await tester.pumpAndSettle();
          expect(controller.submissions, hasLength(1));
          expect(find.text('2/2'), findsOneWidget);
          expect(controller.submissions.single.cardId, 'a');
          expect(tester.takeException(), isNull, reason: 'next card');
        },
      );

      testWidgets(
        '${mode.name} at ${viewport.name} exposes each rating button',
        (tester) async {
          await _pump(
            tester,
            cards: [_card('a', mode), _card('b', mode)],
            size: viewport.size,
            textScale: viewport.textScale,
          );
          await _answer(tester, mode);
          await tester.pumpAndSettle();
          for (final label in ['Encore', 'Difficile', 'Correct', 'Facile']) {
            final finder = find.text(label);
            expect(finder, findsOneWidget);
            await tester.ensureVisible(finder);
            await tester.pump();
            final rect = tester.getRect(finder);
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.bottom, lessThanOrEqualTo(viewport.size.height));
          }
          expect(
            find.byKey(const Key('inline-review-controls')),
            findsOneWidget,
          );
          expect(find.text('COMMENT TU T’EN ES SORTI ?'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('free text keeps field and Vérifier visible with keyboard open', (
    tester,
  ) async {
    const keyboard = 280.0;
    final controller = await _pump(
      tester,
      cards: [_card('a', TestMode.freeText), _card('b', TestMode.freeText)],
      size: const Size(320, 568),
      keyboard: keyboard,
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pumpAndSettle();

    final visibleBottom = 568 - keyboard;
    final field = tester.getRect(find.byType(TextField));
    final button = tester.getRect(find.text('Vérifier'));
    expect(field.top, greaterThanOrEqualTo(0));
    expect(field.bottom, lessThanOrEqualTo(visibleBottom));
    expect(button.top, greaterThanOrEqualTo(0));
    expect(button.bottom, lessThanOrEqualTo(visibleBottom));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Explication'));
    expect(controller.submissions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validating free text keeps the same EditableTextState', (
    tester,
  ) async {
    await _pump(
      tester,
      cards: [_card('a', TestMode.freeText)],
      size: const Size(360, 800),
    );
    await tester.enterText(find.byType(TextField), 'ma réponse');
    await tester.pump();
    final before = tester.state<EditableTextState>(find.byType(EditableText));

    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();

    final after = tester.state<EditableTextState>(find.byType(EditableText));
    expect(identical(before, after), isTrue);
    expect(find.text('ma réponse'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.text('Vérifier'), findsNothing);
  });

  testWidgets('validating an MCQ answer keeps the same mode element', (
    tester,
  ) async {
    await _pump(
      tester,
      cards: [_card('a', TestMode.multipleChoice)],
      size: const Size(360, 800),
    );
    final key = find.byKey(const ValueKey('multipleChoice-a'));
    expect(key, findsOneWidget);
    final before = tester.element(key);

    await _reachAndTap(tester, _lastOption(tester));
    await tester.pump(const Duration(milliseconds: 50));

    expect(key, findsOneWidget);
    expect(identical(tester.element(key), before), isTrue);
    expect(find.textContaining('Bonne réponse longue a'), findsWidgets);
  });

  testWidgets('swipe up reveals a short flashcard', (tester) async {
    await _pump(
      tester,
      cards: [
        _card('a', TestMode.classicFlashcard, question: 'Court', hint: null),
      ],
      size: const Size(360, 800),
    );
    expect(find.text('Révéler la réponse'), findsOneWidget);
    await tester.fling(
      find.text('Glisse vers le haut'),
      const Offset(0, -300),
      1500,
    );
    await tester.pumpAndSettle();
    expect(find.text('Révéler la réponse'), findsNothing);
    expect(find.text('RÉPONSE'), findsOneWidget);
  });

  testWidgets('on a long flashcard dragging scrolls instead of revealing', (
    tester,
  ) async {
    await _pump(
      tester,
      cards: [_card('a', TestMode.classicFlashcard, question: '$_long $_long')],
      size: const Size(320, 568),
      textScale: 1.5,
    );
    final scrollable = find.descendant(
      of: find.byKey(const Key('desktop-study-content')),
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    await tester.drag(scrollable, const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    expect(find.text('Révéler la réponse'), findsOneWidget);

    await tester.tap(find.text('Révéler la réponse'));
    await tester.pumpAndSettle();
    expect(find.text('Révéler la réponse'), findsNothing);
    expect(find.text('COMMENT TU T’EN ES SORTI ?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion shows the next card after a single pump', (
    tester,
  ) async {
    final controller = await _pump(
      tester,
      cards: [
        _card('a', TestMode.multipleChoice),
        _card('b', TestMode.multipleChoice),
      ],
      size: const Size(360, 800),
      reduceMotion: true,
    );
    await _reachAndTap(tester, _lastOption(tester));
    await _reachAndTap(tester, find.text('Correct'));
    await tester.pump();
    expect(controller.submissions, hasLength(1));
    expect(find.textContaining('Bonne réponse longue a'), findsNothing);
    expect(find.text('2/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeStudyController extends StudyController {
  _FakeStudyController({required StudySessionState initialState})
    : _initialState = initialState,
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
  final List<({String cardId, ReviewResult result, bool wasCorrect})>
  submissions = [];

  @override
  Future<StudySessionState> load({
    String? collectionId,
    String? deckId,
    TestMode? forcedMode,
    required int sessionCardLimit,
  }) async => _initialState;

  @override
  Future<void> submitReview({
    required String cardId,
    required ReviewResult result,
    required bool wasCorrect,
    required TestMode playedMode,
  }) async {
    submissions.add((cardId: cardId, result: result, wasCorrect: wasCorrect));
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
