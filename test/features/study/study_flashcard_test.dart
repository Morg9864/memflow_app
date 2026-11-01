import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    'cellulaire qui garantissent la fidélité de la copie du génome. '
    'Elle continue encore et encore pour dépasser largement la hauteur '
    'd’un petit écran, même sans agrandissement du texte système, afin de '
    'forcer le défilement de la zone de contenu de la session de révision.';
const _hint = 'Glisse vers le haut';
const _q = 'Capitale de la France ?';
const _a = 'Paris';

StudyCard _card(
  String id,
  TestMode mode, {
  String question = _q,
  String answer = _a,
}) => StudyCard(
  id: id,
  collectionId: 'bio',
  deckId: 'deck-1',
  question: question,
  correctAnswer: answer,
  wrongAnswers: const [],
  hint: 'Pense à la Seine.',
  explanation: 'Depuis des siècles.',
  currentTestMode: mode,
  allowedTestModes: [mode],
  clozeText: null,
  clozeAnswers: const [],
  clozeWordBank: const [],
  acceptedAnswers: const [],
  level: 2,
);

StudySessionState _state(List<StudyCard> cards) => StudySessionState(
  deckTitle: 'Deck',
  collectionId: 'bio',
  deckId: 'deck-1',
  cards: cards,
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

Future<void> _pump(
  WidgetTester tester, {
  required List<StudyCard> cards,
  Size size = const Size(360, 800),
  double textScale = 1,
  bool reduceMotion = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = _FakeStudyController(initialState: _state(cards));
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        scaffoldMessengerKey: appScaffoldMessengerKey,
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
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
}

/// Flip transform: the only Transform with a perspective entry.
Finder _flipAncestor(Finder of) => find.ancestor(
  of: of,
  matching: find.byWidgetPredicate(
    (w) => w is Transform && w.transform.entry(3, 2).abs() > 1e-6,
  ),
);

/// The swipe hint stays laid out (no layout shift) but is hidden on overflow.
bool _hintVisible(WidgetTester tester) => tester
    .widget<Visibility>(
      find.ancestor(of: find.text(_hint), matching: find.byType(Visibility)),
    )
    .visible;

/// Starts the reveal and advances [ms] into the flip.
Future<void> _revealAndAdvance(WidgetTester tester, int ms) async {
  await tester.tap(find.text('Révéler la réponse'));
  await tester.pump(); // builds, starts the ticker
  await tester.pump(); // first tick: elapsed is zero
  await tester.pump(Duration(milliseconds: ms));
}

void main() {
  const modes = [TestMode.classicFlashcard, TestMode.reversedFlashcard];

  group('card container', () {
    for (final mode in modes) {
      testWidgets('${mode.name}: front and back share the same card width', (
        tester,
      ) async {
        await _pump(tester, cards: [_card('a', mode)]);
        final front = tester.getRect(find.byType(Card).first);
        await tester.tap(find.text('Révéler la réponse'));
        await tester.pumpAndSettle();
        final back = tester.getRect(find.byType(Card).first);
        expect(back.left, front.left);
        expect(back.width, front.width);
      });
    }

    for (final size in const [Size(320, 568), Size(360, 800)]) {
      for (final scale in const [1.0, 2.0]) {
        for (final long in const [false, true]) {
          for (final mode in modes) {
            testWidgets(
              '${mode.name} ${size.width.toInt()}x${size.height.toInt()} '
              '@$scale ${long ? 'long' : 'short'} has no exception',
              (tester) async {
                await _pump(
                  tester,
                  size: size,
                  textScale: scale,
                  cards: [
                    _card(
                      'a',
                      mode,
                      question: long ? _long : _q,
                      answer: long ? _long : _a,
                    ),
                  ],
                );
                expect(tester.takeException(), isNull);
                await tester.tap(find.text('Révéler la réponse'));
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
              },
            );
          }
        }
      }
    }
  });

  group('flip', () {
    testWidgets('runs 260ms, shows the right face and ends unmirrored', (
      tester,
    ) async {
      await _pump(tester, cards: [_card('a', TestMode.classicFlashcard)]);
      expect(find.text(_a), findsNothing);
      expect(_flipAncestor(find.text(_q)), findsNothing);

      await _revealAndAdvance(tester, 26); // 10 % : still the front
      expect(_flipAncestor(find.text(_q)), findsOneWidget);
      expect(find.text(_a), findsNothing);

      await tester.pump(const Duration(milliseconds: 39)); // 25 % : past half
      expect(find.text(_a), findsOneWidget);
      expect(find.text(_hint), findsNothing);
      expect(_flipAncestor(find.text(_a)), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 130)); // 75 %
      expect(find.text(_a), findsOneWidget);
      expect(_flipAncestor(find.text(_a)), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 70)); // 100 %
      await tester.pump();
      expect(find.text(_a), findsOneWidget);
      expect(_flipAncestor(find.text(_a)), findsNothing);
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'settled after 260ms',
      );
    });

    testWidgets('back text is mirrored back mid-flip, plain at rest', (
      tester,
    ) async {
      await _pump(tester, cards: [_card('a', TestMode.classicFlashcard)]);
      await _revealAndAdvance(tester, 130);
      final mirrors = find.ancestor(
        of: find.text(_a),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Transform &&
              w.transform.entry(3, 2) == 0 &&
              (w.transform.entry(0, 0) + 1).abs() < 1e-9,
        ),
      );
      expect(mirrors, findsOneWidget);
      await tester.pumpAndSettle();
      expect(mirrors, findsNothing);
    });

    testWidgets('next card starts on its front without animation', (
      tester,
    ) async {
      await _pump(
        tester,
        cards: [
          _card('a', TestMode.classicFlashcard),
          _card('b', TestMode.classicFlashcard, question: 'Autre ?'),
        ],
      );
      await tester.tap(find.text('Révéler la réponse'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Correct'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Autre ?'), findsOneWidget);
      expect(find.text(_hint), findsOneWidget);
      expect(_flipAncestor(find.text('Autre ?')), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Autre ?'), findsOneWidget);
    });

    testWidgets('reduced motion swaps after one pump, no rotation', (
      tester,
    ) async {
      await _pump(
        tester,
        cards: [_card('a', TestMode.classicFlashcard)],
        reduceMotion: true,
      );
      await tester.tap(find.text('Révéler la réponse'));
      await tester.pump();
      expect(find.text(_a), findsOneWidget);
      expect(find.byType(AnimatedSize), findsNothing);
      expect(_flipAncestor(find.text(_a)), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('semantics', () {
    testWidgets('only the visible face is exposed', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, cards: [_card('a', TestMode.classicFlashcard)]);
      expect(find.bySemanticsLabel(RegExp('Capitale')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(_a)), findsNothing);

      await _revealAndAdvance(tester, 195); // 75 %
      expect(find.bySemanticsLabel(RegExp(_a)), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(_hint)), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('Capitale')),
        findsOneWidget,
      ); // back repeats it once

      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp(_a)), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Capitale')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(_hint)), findsNothing);
      handle.dispose();
    });
  });

  group('gesture', () {
    testWidgets('swipe up reveals a short card', (tester) async {
      await _pump(tester, cards: [_card('a', TestMode.classicFlashcard)]);
      expect(_hintVisible(tester), isTrue);
      await tester.fling(find.text(_q), const Offset(0, -300), 1000);
      await tester.pumpAndSettle();
      expect(find.text(_a), findsOneWidget);
    });

    testWidgets('long card: no hint, drag scrolls, button reveals', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(320, 568),
        cards: [_card('a', TestMode.classicFlashcard, question: _long)],
      );
      await tester.pump();
      expect(_hintVisible(tester), isFalse);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.pixels, 0);
      await tester.fling(find.text('QUESTION'), const Offset(0, -150), 1000);
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(0));
      expect(find.text('Révéler la réponse'), findsOneWidget);
      await tester.tap(find.text('Révéler la réponse'));
      await tester.pumpAndSettle();
      expect(find.text('Révéler la réponse'), findsNothing);
      expect(find.text(_a), findsOneWidget);
    });
  });

  group('scroll fade', () {
    double opacity(WidgetTester t) => t
        .widget<AnimatedOpacity>(find.byKey(const Key('study-scroll-fade')))
        .opacity;

    testWidgets('absent for short content', (tester) async {
      await _pump(tester, cards: [_card('a', TestMode.classicFlashcard)]);
      await tester.pumpAndSettle();
      expect(opacity(tester), 0);
    });

    testWidgets('ignores a text field scrolling its own content', (
      tester,
    ) async {
      await _pump(tester, cards: [_card('a', TestMode.freeText)]);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'très long ' * 40);
      await tester.pumpAndSettle();
      // Field scrolled back to its start: it still has more text to its right.
      tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(TextField),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(opacity(tester), 0);
    });

    testWidgets('shown when scrollable, hidden at the end', (tester) async {
      await _pump(
        tester,
        size: const Size(320, 568),
        cards: [_card('a', TestMode.classicFlashcard, question: _long)],
      );
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
      final fade = find.byKey(const Key('study-scroll-fade'));
      expect(
        find.ancestor(of: fade, matching: find.byType(IgnorePointer)),
        findsWidgets,
      );
      expect(
        find.ancestor(of: fade, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
      await tester.fling(find.text('QUESTION'), const Offset(0, -2000), 3000);
      await tester.pumpAndSettle();
      expect(opacity(tester), 0);
    });
  });

  group('keyboard', () {
    for (final entry in {
      'Space': LogicalKeyboardKey.space,
      'Enter': LogicalKeyboardKey.enter,
    }.entries) {
      testWidgets('${entry.key} reveals', (tester) async {
        await _pump(tester, cards: [_card('a', TestMode.classicFlashcard)]);
        // The study Focus sits above its Shortcuts: keys need focus inside.
        Focus.of(
          tester.element(find.text('Révéler la réponse')),
        ).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(entry.value);
        await tester.pumpAndSettle();
        expect(find.text(_a), findsOneWidget);
      });
    }
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
  }) async {}

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
