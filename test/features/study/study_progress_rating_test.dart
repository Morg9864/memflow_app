import 'dart:convert';
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
import 'package:memflow/widgets/ui.dart';
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
    progressDots: 4,
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
  double textScale = 1.0,
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

const _ratings = ['Encore', 'Difficile', 'Correct', 'Facile'];

const _viewports = <(String, Size, double)>[
  ('320x568', Size(320, 568), 1.0),
  ('360x800', Size(360, 800), 1.0),
  ('360x800 @2.0', Size(360, 800), 2.0),
];

Future<void> _answer(WidgetTester tester, TestMode mode) async {
  switch (mode) {
    case TestMode.multipleChoice:
      await _tap(tester, find.text(_good));
    case TestMode.trueFalse:
      await _tap(
        tester,
        find.text(find.text(_good).evaluate().isNotEmpty ? 'Vrai' : 'Faux'),
      );
    case TestMode.cloze:
      await _fillCloze(tester, ['réplication', 'hélicase']);
    case TestMode.freeText:
      await tester.enterText(find.byType(TextField), _good);
      await _tap(tester, find.text('Vérifier'));
    case TestMode.classicFlashcard:
    case TestMode.reversedFlashcard:
      await _tap(tester, find.text('Révéler la réponse'));
  }
}

/// Top of the section label to the bottom of the grid, plus the 8px gap
/// above the pinned area.
double _pinnedHeight(WidgetTester tester) {
  final top = tester.getRect(find.text('COMMENT TU T’EN ES SORTI ?')).top;
  final bottom = tester
      .getRect(find.byKey(const Key('inline-review-controls')))
      .bottom;
  return bottom - top + 8;
}

Finder _button(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(Pressable));

/// The bundled fonts, so text widths match the app (the default test font
/// is much wider and would wrap everything).
Future<void> _loadFonts() async {
  final manifest =
      jsonDecode(
            utf8.decode(
              (await rootBundle.load('FontManifest.json')).buffer.asUint8List(),
            ),
          )
          as List;
  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    for (final f in entry['fonts'] as List) {
      loader.addFont(rootBundle.load(f['asset'] as String));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  group('pinned rating block', () {
    testWidgets('takes at most 24% of a 360x800 screen', (tester) async {
      await _pump(
        tester,
        cards: [
          _card('a', TestMode.multipleChoice),
          _card('b', TestMode.cloze),
        ],
      );
      await _answer(tester, TestMode.multipleChoice);
      final height = _pinnedHeight(tester);
      expect(height / 800, lessThanOrEqualTo(0.24));
      expect(tester.takeException(), isNull);
    });

    testWidgets('label and description are dark, icon carries the tone', (
      tester,
    ) async {
      await _pump(tester, cards: [_card('a', TestMode.multipleChoice)]);
      await _answer(tester, TestMode.multipleChoice);
      const tones = {
        'Encore': (Icons.refresh_rounded, AppColors.error),
        'Difficile': (Icons.terrain_rounded, AppColors.ratingHard),
        'Correct': (Icons.thumb_up_alt_rounded, AppColors.resultGood),
        'Facile': (Icons.rocket_launch_rounded, AppColors.ratingEasy),
      };
      const descriptions = {
        'Encore': 'Je ne savais pas',
        'Difficile': 'Avec effort',
        'Correct': 'Je savais',
        'Facile': 'Trop simple',
      };
      for (final entry in tones.entries) {
        final button = _button(entry.key);
        expect(
          tester.widget<Text>(find.text(entry.key)).style!.color,
          AppColors.text,
        );
        expect(
          tester.widget<Text>(find.text(descriptions[entry.key]!)).style!.color,
          AppColors.text,
        );
        final icon = tester.widget<Icon>(
          find.descendant(of: button, matching: find.byIcon(entry.value.$1)),
        );
        expect(icon.color, entry.value.$2);
        expect(icon.size, 20);
      }
    });

    testWidgets('suggested state keeps the layout and names itself', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      Future<Map<String, Size>> sizes(String pick) async {
        await _pump(tester, cards: [_card('a', TestMode.multipleChoice)]);
        await _tap(tester, find.text(pick));
        return {for (final l in _ratings) l: tester.getSize(_button(l))};
      }

      // Correct pick suggests "Correct"; wrong pick suggests "Encore".
      final afterRight = await sizes(_good);
      expect(
        find.bySemanticsLabel('Correct, Je savais, suggéré'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Encore, Je ne savais pas'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('inline-review-controls')),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
      final afterWrong = await sizes(_bad1);
      expect(
        find.bySemanticsLabel('Encore, Je ne savais pas, suggéré'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Correct, Je savais'), findsOneWidget);
      expect(afterWrong, afterRight);
      handle.dispose();
    });

    for (final (name, size, scale) in _viewports) {
      for (final result in ReviewResult.values) {
        testWidgets('${result.name} submits once at $name', (tester) async {
          final controller = await _pump(
            tester,
            cards: [
              _card('a', TestMode.multipleChoice),
              _card('b', TestMode.multipleChoice),
            ],
            size: size,
            textScale: scale,
          );
          await _answer(tester, TestMode.multipleChoice);
          await _tap(tester, find.text(_ratings[result.index]));
          expect(controller.submissions, hasLength(1));
          expect(controller.submissions.single.result, result);
          expect(tester.takeException(), isNull);
        });
      }

      for (final mode in TestMode.values) {
        testWidgets('${mode.name} has no exception at $name', (tester) async {
          await _pump(
            tester,
            cards: [_card('a', mode), _card('b', mode)],
            size: size,
            textScale: scale,
          );
          expect(tester.takeException(), isNull, reason: 'before answer');
          await _answer(tester, mode);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'after answer');
          expect(find.text('Encore'), findsOneWidget);
        });
      }
    }

    testWidgets('feedback stays visible above the block (360x800, short)', (
      tester,
    ) async {
      await _pump(
        tester,
        cards: [
          _card('a', TestMode.multipleChoice),
          _card('b', TestMode.cloze),
        ],
      );
      await _tap(tester, find.text(_good));
      final area = tester.getRect(
        find.byKey(const Key('desktop-study-content')),
      );
      final feedback = tester.getRect(
        find
            .ancestor(
              of: find.text('BONNE RÉPONSE'),
              matching: find.byType(Card),
            )
            .first,
      );
      expect(feedback.top, greaterThanOrEqualTo(area.top - 0.5));
      expect(feedback.bottom, lessThanOrEqualTo(area.bottom + 0.5));
      expect(
        tester.getRect(find.text('Encore')).top,
        greaterThanOrEqualTo(feedback.bottom),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('reveal grows the block with the animation', (tester) async {
      await _pump(
        tester,
        cards: [_card('a', TestMode.cloze), _card('b', TestMode.cloze)],
      );
      await _fillCloze(tester, ['réplication', 'hélicase']);
      expect(find.text('Encore'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reveal under reduced motion has no exception', (tester) async {
      await _pump(
        tester,
        cards: [
          _card('a', TestMode.multipleChoice),
          _card('b', TestMode.cloze),
        ],
        reduceMotion: true,
      );
      await tester.tap(find.text(_good));
      await tester.pump();
      expect(find.text('Encore'), findsOneWidget);
      expect(find.byType(AnimatedSize), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('block grows over time when motion is on', (tester) async {
      await _pump(
        tester,
        cards: [_card('a', TestMode.freeText), _card('b', TestMode.freeText)],
      );
      await tester.enterText(find.byType(TextField), _good);
      await tester.pump();
      await tester.tap(find.text('Vérifier'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final early = tester.getSize(find.byType(AnimatedSize).last).height;
      await tester.pumpAndSettle();
      final end = tester.getSize(find.byType(AnimatedSize).last).height;
      expect(early, lessThan(end));
    });
  });

  group('progress header', () {
    testWidgets('counter and semantics follow the card', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        cards: [
          _card('a', TestMode.multipleChoice),
          _card('b', TestMode.multipleChoice),
        ],
      );
      expect(find.text('1/2'), findsOneWidget);
      expect(find.bySemanticsLabel('Carte 1 sur 2'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('1/2')).style!.fontFeatures,
        AppTheme.tabularFigures,
      );
      await _answer(tester, TestMode.multipleChoice);
      await _tap(tester, find.text('Correct'));
      expect(find.text('2/2'), findsOneWidget);
      expect(find.bySemanticsLabel('Carte 2 sur 2'), findsOneWidget);
      expect(find.byTooltip('Quitter la session'), findsOneWidget);
      handle.dispose();
    });

    double value(WidgetTester tester) => tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;

    testWidgets('progress bar animates between cards', (tester) async {
      await _pump(
        tester,
        cards: [
          _card('a', TestMode.multipleChoice),
          _card('b', TestMode.multipleChoice),
        ],
      );
      expect(value(tester), 0.5);
      await _answer(tester, TestMode.multipleChoice);
      await tester.tap(find.text('Correct'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final mid = value(tester);
      expect(mid, greaterThan(0.5));
      expect(mid, lessThan(1.0));
      await tester.pumpAndSettle();
      expect(value(tester), 1.0);
    });

    testWidgets('progress bar is immediate under reduced motion', (
      tester,
    ) async {
      await _pump(
        tester,
        cards: [
          _card('a', TestMode.multipleChoice),
          _card('b', TestMode.multipleChoice),
        ],
        reduceMotion: true,
      );
      await _answer(tester, TestMode.multipleChoice);
      await tester.tap(find.text('Correct'));
      await tester.pump();
      await tester.pump();
      expect(value(tester), 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('two-line title at 2.0 scale does not overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        cards: [_card('a', TestMode.multipleChoice)],
        size: const Size(320, 568),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
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
