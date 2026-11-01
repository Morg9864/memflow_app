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
    'cellulaire qui garantissent la fidélité de la copie du génome.';

const _good = 'Réponse juste';
const _bad1 = 'Réponse fausse un';
const _bad2 = 'Réponse fausse deux';
const _bad3 = 'Réponse fausse trois';

StudyCard _card(
  String id,
  TestMode mode, {
  String question = 'Quelle est la bonne ?',
  String explanation = 'Parce que c’est ainsi.',
  bool longWrong = false,
}) {
  final isCloze = mode == TestMode.cloze;
  return StudyCard(
    id: id,
    collectionId: 'bio',
    deckId: 'deck-1',
    question: question,
    correctAnswer: isCloze ? 'réplication' : _good,
    wrongAnswers: longWrong
        ? const ['$_bad1 $_long', '$_bad2 $_long', '$_bad3 $_long']
        : const [_bad1, _bad2, _bad3],
    hint: 'Pense à la fourche.',
    explanation: explanation,
    currentTestMode: mode,
    allowedTestModes: [mode],
    clozeText: isCloze
        ? 'La {{réplication}} est semi-conservative et fait intervenir une '
              '{{hélicase}} puis une polymérase.'
        : null,
    clozeAnswers: isCloze ? const ['réplication', 'hélicase'] : const [],
    clozeWordBank: isCloze
        ? const ['réplication', 'hélicase', 'ribosome', 'glycolyse']
        : const [],
    acceptedAnswers: const [],
    level: 2,
  );
}

StudySessionState _state(List<StudyCard> cards) {
  return StudySessionState(
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
}

Future<_FakeStudyController> _pump(
  WidgetTester tester, {
  required List<StudyCard> cards,
  Size size = const Size(360, 800),
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
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
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

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _fillCloze(WidgetTester tester, List<String> words) async {
  for (final word in words) {
    await _tap(tester, find.text('_____'));
    await _tap(tester, find.text(word));
  }
  await _tap(tester, find.text('Valider ma réponse'));
}

/// The decorated container of the option tile showing [text].
Finder _tileBox(String text) => find.ancestor(
  of: find.text(text).first,
  matching: find.byType(AnimatedContainer),
);

BoxDecoration _decoration(WidgetTester tester, Finder box) =>
    tester.widget<AnimatedContainer>(box.first).decoration! as BoxDecoration;

Color _borderColor(WidgetTester tester, Finder box) =>
    (_decoration(tester, box).border! as Border).top.color;

/// Label of the option that is right: the proposition shown is either the
/// right answer ("Vrai" is right) or a wrong one ("Faux" is right).
String _rightTrueFalse() =>
    find.text(_good).evaluate().isNotEmpty ? 'Vrai' : 'Faux';

String _wrongTrueFalse() => _rightTrueFalse() == 'Vrai' ? 'Faux' : 'Vrai';

Finder _feedbackCard(String upperLabel) =>
    find.ancestor(of: find.text(upperLabel), matching: find.byType(Card)).first;

Color? _feedbackColor(WidgetTester tester, String upperLabel) =>
    tester.widget<Card>(_feedbackCard(upperLabel)).color;

void main() {
  final theme = AppTheme.light();

  group('questionTextStyle', () {
    final text = theme.textTheme;
    String of(int length) => 'a' * length;

    test('uses headlineMedium under 90 characters', () {
      expect(questionTextStyle(text, of(1)), text.headlineMedium);
      expect(questionTextStyle(text, of(89)), text.headlineMedium);
    });

    test('uses headlineSmall from 90 to 199 characters', () {
      expect(questionTextStyle(text, of(90)), text.headlineSmall);
      expect(questionTextStyle(text, of(199)), text.headlineSmall);
    });

    test('uses titleLarge from 200 characters', () {
      expect(questionTextStyle(text, of(200)), text.titleLarge);
      expect(questionTextStyle(text, of(600)), text.titleLarge);
    });
  });

  group('option tile states', () {
    testWidgets('normal tiles use the surface with a neutral border', (
      tester,
    ) async {
      await _pump(tester, cards: [_card('a', TestMode.multipleChoice)]);
      for (final text in [_good, _bad1, _bad2, _bad3]) {
        final box = _tileBox(text);
        expect(_decoration(tester, box).color, theme.cardTheme.color);
        expect(_borderColor(tester, box), theme.dividerColor);
      }
      expect(find.text('Ta réponse'), findsNothing);
    });

    testWidgets('wrong pick: bad tile, correct tile, quiet tiles', (
      tester,
    ) async {
      await _pump(tester, cards: [_card('a', TestMode.multipleChoice)]);
      await _tap(tester, find.text(_bad1));

      final wrong = _tileBox(_bad1);
      expect(_decoration(tester, wrong).color, AppColors.resultBadSoft);
      expect(_borderColor(tester, wrong), AppColors.resultBad);
      expect(
        find.descendant(
          of: wrong.first,
          matching: find.byIcon(Icons.cancel_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: wrong.first, matching: find.text('Ta réponse')),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.text(_bad1)).style!.color,
        AppColors.resultBadText,
      );

      final right = _tileBox(_good);
      expect(_decoration(tester, right).color, AppColors.resultGoodSoft);
      expect(_borderColor(tester, right), AppColors.resultGood);
      expect(
        find.descendant(
          of: right.first,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: right.first, matching: find.text('Ta réponse')),
        findsNothing,
      );

      for (final text in [_bad2, _bad3]) {
        final quiet = _tileBox(text);
        expect(_decoration(tester, quiet).color, theme.cardTheme.color);
        expect(_borderColor(tester, quiet), theme.dividerColor);
        expect(
          tester.widget<Text>(find.text(text)).style!.color,
          theme.colorScheme.onSurfaceVariant,
        );
        expect(
          find.descendant(of: quiet.first, matching: find.byType(Icon)),
          findsNothing,
        );
      }
      expect(find.text('Ta réponse'), findsOneWidget);
    });

    testWidgets('correct pick shows the caption on the good tile', (
      tester,
    ) async {
      await _pump(tester, cards: [_card('a', TestMode.multipleChoice)]);
      await _tap(tester, find.text(_good));
      final right = _tileBox(_good);
      expect(
        find.descendant(of: right.first, matching: find.text('Ta réponse')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: right.first,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cancel_rounded), findsNothing);
    });

    testWidgets('border width never changes between states', (tester) async {
      await _pump(tester, cards: [_card('a', TestMode.multipleChoice)]);
      double width(String text) =>
          (_decoration(tester, _tileBox(text)).border! as Border).top.width;
      final before = width(_bad2);
      await _tap(tester, find.text(_bad1));
      expect(width(_bad1), before);
      expect(width(_good), before);
      expect(width(_bad2), before);
    });

    testWidgets('semantics name the result and the user pick', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, cards: [_card('a', TestMode.multipleChoice)]);
      await _tap(tester, find.text(_bad1));

      expect(
        find.bySemanticsLabel(
          RegExp(r'^[A-D]\. Réponse fausse un, mauvaise réponse, ta réponse$'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'^[A-D]\. Réponse juste, bonne réponse$'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^[A-D]\. Réponse fausse deux$')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('true/false uses the same states', (tester) async {
      await _pump(tester, cards: [_card('a', TestMode.trueFalse)]);
      final right = _rightTrueFalse();
      final wrongLabel = _wrongTrueFalse();
      await _tap(tester, find.text(wrongLabel));
      final wrong = _tileBox(wrongLabel);
      expect(_decoration(tester, wrong).color, AppColors.resultBadSoft);
      expect(
        find.descendant(of: wrong.first, matching: find.text('Ta réponse')),
        findsOneWidget,
      );
      final good = _tileBox(right);
      expect(_decoration(tester, good).color, AppColors.resultGoodSoft);
      expect(
        find.descendant(
          of: good.first,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
    });
  });

  group('feedback card', () {
    testWidgets('MCQ right and wrong', (tester) async {
      await _pump(tester, cards: [_card('a', TestMode.multipleChoice)]);
      await _tap(tester, find.text(_good));
      expect(_feedbackColor(tester, 'BONNE RÉPONSE'), AppColors.resultGoodSoft);
      expect(
        find.descendant(
          of: _feedbackCard('BONNE RÉPONSE'),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
      expect(find.text('Parce que c’est ainsi.'), findsOneWidget);
    });

    testWidgets('MCQ wrong', (tester) async {
      await _pump(tester, cards: [_card('a', TestMode.multipleChoice)]);
      await _tap(tester, find.text(_bad2));
      expect(
        _feedbackColor(tester, 'RÉPONSE ATTENDUE'),
        AppColors.resultBadSoft,
      );
      expect(
        find.descendant(
          of: _feedbackCard('RÉPONSE ATTENDUE'),
          matching: find.byIcon(Icons.cancel_rounded),
        ),
        findsNWidgets(1),
      );
    });

    testWidgets('true/false right and wrong keep one label', (tester) async {
      await _pump(tester, cards: [_card('a', TestMode.trueFalse)]);
      await _tap(tester, find.text(_rightTrueFalse()));
      expect(
        _feedbackColor(tester, 'RÉPONSE CORRECTE'),
        AppColors.resultGoodSoft,
      );

      await _pump(tester, cards: [_card('b', TestMode.trueFalse)]);
      await _tap(tester, find.text(_wrongTrueFalse()));
      expect(
        _feedbackColor(tester, 'RÉPONSE CORRECTE'),
        AppColors.resultBadSoft,
      );
    });

    testWidgets('free text right and wrong', (tester) async {
      await _pump(tester, cards: [_card('a', TestMode.freeText)]);
      await tester.enterText(find.byType(TextField), _good);
      await _tap(tester, find.text('Vérifier'));
      expect(_feedbackColor(tester, 'BIEN JOUÉ'), AppColors.resultGoodSoft);

      await _pump(tester, cards: [_card('b', TestMode.freeText)]);
      await tester.enterText(find.byType(TextField), 'rien à voir');
      await _tap(tester, find.text('Vérifier'));
      expect(_feedbackColor(tester, 'RÉPONSE'), AppColors.resultBadSoft);
    });

    testWidgets('cloze right and wrong', (tester) async {
      await _pump(tester, cards: [_card('a', TestMode.cloze)]);
      await _fillCloze(tester, ['réplication', 'hélicase']);
      expect(_feedbackColor(tester, 'BIEN JOUÉ'), AppColors.resultGoodSoft);

      await _pump(tester, cards: [_card('b', TestMode.cloze)]);
      await _fillCloze(tester, ['ribosome', 'glycolyse']);
      expect(_feedbackColor(tester, 'TEXTE COMPLÉTÉ'), AppColors.resultBadSoft);
    });

    Future<(Rect, Rect, double)> answerAndMeasure(
      WidgetTester tester,
      StudyCard card, {
      Size size = const Size(360, 800),
      bool reduceMotion = false,
    }) async {
      await _pump(
        tester,
        cards: [card, _card('b', TestMode.multipleChoice)],
        size: size,
        reduceMotion: reduceMotion,
      );
      await _tap(tester, find.text(_good));
      final areaFinder = find.byKey(const Key('desktop-study-content'));
      final scrollable = find.descendant(
        of: areaFinder,
        matching: find.byType(Scrollable),
      );
      return (
        tester.getRect(areaFinder),
        tester.getRect(_feedbackCard('BONNE RÉPONSE')),
        tester.state<ScrollableState>(scrollable.first).position.pixels,
      );
    }

    testWidgets('scrolls into view above the pinned ratings (360x800)', (
      tester,
    ) async {
      final (area, feedback, pixels) = await answerAndMeasure(
        tester,
        _card('a', TestMode.multipleChoice, longWrong: true),
      );
      expect(pixels, greaterThan(0), reason: 'it was below the fold');
      expect(feedback.top, greaterThanOrEqualTo(area.top - 0.5));
      expect(feedback.bottom, lessThanOrEqualTo(area.bottom + 0.5));
      // The pinned ratings sit below the scroll area, not over the card.
      expect(
        tester.getRect(find.text('Encore')).top,
        greaterThanOrEqualTo(feedback.bottom),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls into view with reduced motion too', (tester) async {
      final (area, feedback, pixels) = await answerAndMeasure(
        tester,
        _card('a', TestMode.multipleChoice, longWrong: true),
        reduceMotion: true,
      );
      expect(pixels, greaterThan(0));
      expect(feedback.bottom, lessThanOrEqualTo(area.bottom + 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a card taller than the screen is aligned on its top', (
      tester,
    ) async {
      final (area, feedback, pixels) = await answerAndMeasure(
        tester,
        _card(
          'a',
          TestMode.multipleChoice,
          longWrong: true,
          explanation: 'Explication détaillée. $_long $_long',
        ),
      );
      expect(feedback.height, greaterThan(area.height));
      expect(pixels, greaterThan(0));
      expect(feedback.top, closeTo(area.top, 1));
    });

    testWidgets('does not scroll when the card is already visible', (
      tester,
    ) async {
      final (area, feedback, pixels) = await answerAndMeasure(
        tester,
        _card('a', TestMode.multipleChoice),
        size: const Size(360, 1600),
      );
      expect(pixels, 0);
      expect(feedback.bottom, lessThanOrEqualTo(area.bottom + 0.5));
    });
  });

  group('free text field', () {
    testWidgets('has keyboard submit, sentences, no autofocus', (tester) async {
      await _pump(tester, cards: [_card('a', TestMode.freeText)]);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textInputAction, TextInputAction.done);
      expect(field.textCapitalization, TextCapitalization.sentences);
      expect(field.autofocus, isFalse);
    });

    testWidgets('keyboard done submits like the button', (tester) async {
      await _pump(tester, cards: [_card('a', TestMode.freeText)]);
      await tester.enterText(find.byType(TextField), 'ma réponse');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Vérifier'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(find.text('RÉPONSE'), findsOneWidget);
      // Wrong answer: bad tone border icon on the field.
      expect(find.byIcon(Icons.cancel_rounded), findsWidgets);
    });

    testWidgets('keyboard done on an empty field behaves as the button', (
      tester,
    ) async {
      await _pump(tester, cards: [_card('a', TestMode.freeText)]);
      await tester.tap(find.byType(TextField));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Vérifier'), findsNothing);
      expect(find.text('RÉPONSE'), findsOneWidget);
    });

    testWidgets('a right answer shows a check on the field', (tester) async {
      await _pump(tester, cards: [_card('a', TestMode.freeText)]);
      await tester.enterText(find.byType(TextField), _good);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(TextField),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
    });
  });

  group('cloze chips', () {
    testWidgets('expose button semantics with gap number and content', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, cards: [_card('a', TestMode.cloze)]);
      expect(find.bySemanticsLabel('Trou 1, vide'), findsOneWidget);
      expect(find.bySemanticsLabel('Trou 2, vide'), findsOneWidget);
      expect(find.bySemanticsLabel('hélicase'), findsOneWidget);

      await _tap(tester, find.text('_____'));
      await _tap(tester, find.text('réplication'));
      expect(find.bySemanticsLabel('Trou 1, réplication'), findsOneWidget);
      expect(find.bySemanticsLabel('Trou 2, vide'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('semantics name the verdict after validation', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, cards: [_card('a', TestMode.cloze)]);
      await _fillCloze(tester, ['réplication', 'ribosome']);
      expect(
        find.bySemanticsLabel('Trou 1, réplication, bonne réponse'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Trou 2, ribosome, mauvaise réponse'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('chips are at least 44 high and validated ones get an icon', (
      tester,
    ) async {
      await _pump(tester, cards: [_card('a', TestMode.cloze)]);
      expect(
        tester.getSize(find.widgetWithText(InkWell, '_____').first).height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester.getSize(find.widgetWithText(InkWell, 'ribosome').first).height,
        greaterThanOrEqualTo(44),
      );
      await _fillCloze(tester, ['réplication', 'ribosome']);
      final first = find.widgetWithText(InkWell, 'réplication');
      final second = find.widgetWithText(InkWell, 'ribosome');
      expect(
        find.descendant(
          of: first.first,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: second.first,
          matching: find.byIcon(Icons.cancel_rounded),
        ),
        findsOneWidget,
      );
    });
  });

  group('haptics', () {
    late List<String> haptics;

    setUp(() => haptics = []);

    void listen(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    testWidgets('one light impact on validation, none on rating', (
      tester,
    ) async {
      listen(tester);
      await _pump(
        tester,
        cards: [
          _card('a', TestMode.multipleChoice),
          _card('b', TestMode.multipleChoice),
        ],
      );
      expect(haptics, isEmpty);
      await _tap(tester, find.text(_bad1));
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      await _tap(tester, find.text('Correct'));
      expect(haptics, hasLength(1), reason: 'rating must stay silent');
    });

    testWidgets('free text, true/false, cloze and flashcard reveal', (
      tester,
    ) async {
      listen(tester);
      await _pump(tester, cards: [_card('a', TestMode.freeText)]);
      await tester.enterText(find.byType(TextField), 'x');
      await _tap(tester, find.text('Vérifier'));
      expect(haptics, hasLength(1));

      await _pump(tester, cards: [_card('b', TestMode.trueFalse)]);
      await _tap(tester, find.text('Vrai'));
      expect(haptics, hasLength(2));

      await _pump(tester, cards: [_card('c', TestMode.cloze)]);
      await _tap(tester, find.text('_____'));
      await _tap(tester, find.text('réplication'));
      expect(
        haptics,
        hasLength(2),
        reason: 'filling a gap is not a validation',
      );
      await _tap(tester, find.text('Valider ma réponse'));
      expect(haptics, hasLength(3));

      await _pump(tester, cards: [_card('d', TestMode.classicFlashcard)]);
      await _tap(tester, find.text('Révéler la réponse'));
      expect(haptics, hasLength(4));
    });
  });

  group('reduced motion', () {
    for (final mode in [
      TestMode.multipleChoice,
      TestMode.trueFalse,
      TestMode.freeText,
      TestMode.cloze,
    ]) {
      testWidgets('${mode.name} answers without exceptions', (tester) async {
        await _pump(
          tester,
          cards: [_card('a', mode), _card('b', mode)],
          reduceMotion: true,
        );
        switch (mode) {
          case TestMode.multipleChoice:
            await _tap(tester, find.text(_bad1));
          case TestMode.trueFalse:
            await _tap(tester, find.text('Faux'));
          case TestMode.freeText:
            await tester.enterText(find.byType(TextField), 'x');
            await _tap(tester, find.text('Vérifier'));
          default:
            await _fillCloze(tester, ['ribosome', 'glycolyse']);
        }
        expect(tester.takeException(), isNull);
        expect(find.text('Encore'), findsOneWidget);
        await _tap(tester, find.text('Correct'));
        expect(tester.takeException(), isNull);
        expect(find.text('2/2'), findsOneWidget);
      });
    }

    testWidgets('tiles do not animate', (tester) async {
      await _pump(
        tester,
        cards: [_card('a', TestMode.multipleChoice)],
        reduceMotion: true,
      );
      expect(
        tester.widget<AnimatedContainer>(_tileBox(_good).first).duration,
        Duration.zero,
      );
      await tester.tap(find.text(_bad1));
      await tester.pump();
      // A single frame is enough: the feedback is fully there, no tween.
      expect(
        _feedbackColor(tester, 'RÉPONSE ATTENDUE'),
        AppColors.resultBadSoft,
      );
      expect(
        find.ancestor(
          of: find.text('RÉPONSE ATTENDUE'),
          matching: find.byType(TweenAnimationBuilder<double>),
        ),
        findsNothing,
      );
    });
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
