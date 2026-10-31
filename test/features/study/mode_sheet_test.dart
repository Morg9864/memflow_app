import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/app/providers.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/card_mode_service.dart';
import 'package:memflow/features/study/mode_selection_sheet.dart';
import 'package:memflow/features/study/study_controller.dart';
import 'package:memflow/features/study/study_screen.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _availability = StudyModeAvailability(
  total: 40,
  compatible: {
    TestMode.multipleChoice: 40,
    TestMode.classicFlashcard: 38,
    TestMode.reversedFlashcard: 37,
    TestMode.cloze: 12,
    TestMode.freeText: 25,
    TestMode.trueFalse: 0,
  },
);

const _rows = <(String, TestMode?)>[
  ('Adaptatif', null),
  ('QCM', TestMode.multipleChoice),
  ('Vrai / Faux', TestMode.trueFalse),
  ('Flashcard', TestMode.classicFlashcard),
  ('Flashcard inversée', TestMode.reversedFlashcard),
  ('Saisie libre', TestMode.freeText),
  ('Texte à trous', TestMode.cloze),
];

typedef _Viewport = ({String name, Size size, double textScale});

const _viewports = <_Viewport>[
  (name: '320x568', size: Size(320, 568), textScale: 1.0),
  (name: '360x800', size: Size(360, 800), textScale: 1.0),
  (name: '360x800 @2.0', size: Size(360, 800), textScale: 2.0),
];

void _setView(WidgetTester tester, Size size, [double textScale = 1.0]) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// Opens the sheet from a button; the completer receives the sheet's value.
Future<Completer<ModeChoice?>> _openSheet(WidgetTester tester) async {
  final result = Completer<ModeChoice?>();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => result.complete(
                await showModeSelectionSheet(
                  context,
                  availability: _availability,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('mode sheet', () {
    for (final (label, mode) in _rows) {
      if (mode == TestMode.trueFalse) continue;
      testWidgets('$label returns its ModeChoice', (tester) async {
        _setView(tester, const Size(360, 800));
        final result = await _openSheet(tester);
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        final choice = await result.future;
        expect(choice, isNotNull);
        expect(choice!.mode, mode);
      });
    }

    testWidgets('dismiss returns null', (tester) async {
      _setView(tester, const Size(360, 800));
      final result = await _openSheet(tester);
      Navigator.of(tester.element(find.text('Mode de session'))).pop();
      await tester.pumpAndSettle();
      expect(await result.future, isNull);
    });

    testWidgets('renders counts', (tester) async {
      _setView(tester, const Size(360, 800));
      await _openSheet(tester);
      expect(find.text('40 cartes'), findsOneWidget);
      expect(find.text('12 / 40 compatibles'), findsOneWidget);
      expect(find.text('0 / 40 compatibles'), findsOneWidget);
    });

    testWidgets('a 0-compatible mode is not tappable and reads as disabled', (
      tester,
    ) async {
      _setView(tester, const Size(360, 800));
      final result = await _openSheet(tester);
      final handle = tester.ensureSemantics();
      final disabled = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^Vrai / Faux')),
      );
      final enabled = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^QCM')),
      );
      expect(disabled.getSemanticsData().hasAction(SemanticsAction.tap), false);
      expect(enabled.getSemanticsData().hasAction(SemanticsAction.tap), true);
      expect(
        disabled.getSemanticsData().flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      expect(
        enabled.getSemanticsData().flagsCollection.isEnabled,
        Tristate.isTrue,
      );
      handle.dispose();

      await tester.ensureVisible(find.text('Vrai / Faux'));
      await tester.tap(find.text('Vrai / Faux'));
      await tester.pumpAndSettle();
      expect(find.text('Mode de session'), findsOneWidget);
      expect(result.isCompleted, isFalse);
    });

    for (final v in _viewports) {
      testWidgets('no overflow and all rows reachable at ${v.name}', (
        tester,
      ) async {
        _setView(tester, v.size, v.textScale);
        await _openSheet(tester);
        expect(tester.takeException(), isNull);
        for (final (label, _) in _rows) {
          await tester.ensureVisible(find.text(label));
          await tester.pump();
          expect(tester.takeException(), isNull);
          final rect = tester.getRect(find.text(label));
          expect(rect.top, greaterThanOrEqualTo(0), reason: label);
          expect(rect.bottom, lessThanOrEqualTo(v.size.height), reason: label);
        }
      });
    }

    testWidgets('uses a dialog with two columns at width >= 720', (
      tester,
    ) async {
      _setView(tester, const Size(900, 900));
      final result = await _openSheet(tester);
      expect(find.byType(Dialog), findsOneWidget);
      final qcm = tester.getTopLeft(find.text('QCM'));
      final tf = tester.getTopLeft(find.text('Vrai / Faux'));
      expect(tf.dy, closeTo(qcm.dy, 1));
      expect(tf.dx, greaterThan(qcm.dx));
      await tester.tap(find.text('Texte à trous'));
      await tester.pumpAndSettle();
      expect((await result.future)!.mode, TestMode.cloze);
    });
  });

  group('study screen behind the sheet', () {
    StudySessionState session() => StudySessionState(
      deckTitle: 'Bio',
      collectionId: 'bio',
      deckId: 'd1',
      cards: const [
        StudyCard(
          id: 'c1',
          collectionId: 'bio',
          deckId: 'd1',
          question: 'Question c1',
          correctAnswer: 'Réponse c1',
          wrongAnswers: ['A', 'B', 'C'],
          hint: null,
          explanation: null,
          currentTestMode: TestMode.multipleChoice,
          allowedTestModes: [TestMode.multipleChoice],
          clozeText: null,
          clozeAnswers: [],
          clozeWordBank: [],
          acceptedAnswers: [],
          level: 1,
          progressDots: 3,
        ),
      ],
      currentIndex: 0,
      revealed: false,
      selectedOptionIndex: null,
      hasValidatedAnswer: false,
      freeTextAnswer: '',
      reviewCounts: const {},
      currentAnswerWasCorrect: null,
      isCompleted: false,
    );

    Future<Completer<StudySessionState>> pumpStudy(
      WidgetTester tester, {
      Object? availabilityError,
    }) async {
      final loading = Completer<StudySessionState>();
      final controller = StudyController.fromPersistence(
        loadSession:
            ({collectionId, deckId, forcedMode, required sessionCardLimit}) =>
                loading.future,
        submitReview:
            ({
              required cardId,
              required reviewResult,
              required wasCorrect,
              required playedMode,
            }) async {},
        modeAvailability: ({collectionId, deckId}) async {
          if (availabilityError != null) throw availabilityError;
          return _availability;
        },
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(
        initialLocation: '/study',
        routes: [
          GoRoute(
            path: '/study',
            builder: (_, _) => StudyScreen(
              collectionId: 'bio',
              deckId: 'd1',
              controller: controller,
            ),
          ),
          GoRoute(
            path: '/collection/:id',
            builder: (_, _) => const Scaffold(body: Text('collection')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      return loading;
    }

    testWidgets('no spinner or Préparation while the sheet is open', (
      tester,
    ) async {
      _setView(tester, const Size(360, 800));
      await pumpStudy(tester);
      await tester.pumpAndSettle();
      expect(find.text('Mode de session'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Préparation'), findsNothing);
    });

    testWidgets('dismissing leaves no spinner or Préparation', (tester) async {
      _setView(tester, const Size(360, 800));
      await pumpStudy(tester);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Mode de session'))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Préparation'), findsNothing);
      expect(find.text('collection'), findsOneWidget);
    });

    testWidgets('a failed availability check shows the error state', (
      tester,
    ) async {
      _setView(tester, const Size(360, 800));
      await pumpStudy(tester, availabilityError: StateError('db'));
      await tester.pumpAndSettle();
      expect(find.text('Session indisponible'), findsOneWidget);
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();
      expect(find.text('collection'), findsOneWidget);
    });

    testWidgets('loading state shows after a choice, then the session', (
      tester,
    ) async {
      _setView(tester, const Size(360, 800));
      final loading = await pumpStudy(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('QCM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Préparation'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      loading.complete(session());
      await tester.pumpAndSettle();
      expect(find.textContaining('Préparation'), findsNothing);
      expect(find.text('Question c1'), findsWidgets);
    });
  });
}
