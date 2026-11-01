// Shared by test/a11y/*: every screen and study mode in the states that matter
// for accessibility checks, with long content, behind Riverpod overrides only.
// (The visual harness keeps its own private copy of similar fixtures.)
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/app/providers.dart';
import 'package:memflow/data/sync/sync_service.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/card_mode_service.dart';
import 'package:memflow/features/auth/auth_screen.dart';
import 'package:memflow/features/collections/collection_detail_screen.dart';
import 'package:memflow/features/home/home_screen.dart';
import 'package:memflow/features/import/import_screen.dart';
import 'package:memflow/features/navigation/not_found_screen.dart';
import 'package:memflow/features/profile/profile_screen.dart';
import 'package:memflow/features/profile/settings_screen.dart';
import 'package:memflow/features/stats/stats_screen.dart';
import 'package:memflow/features/study/mode_selection_sheet.dart';
import 'package:memflow/features/study/session_summary_screen.dart';
import 'package:memflow/features/study/study_controller.dart';
import 'package:memflow/features/study/study_screen.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

/// The bundled fonts, so text widths and pixels match the app. Without them
/// the test font (Ahem) draws solid blocks and contrast checks are meaningless.
Future<void> loadAppFonts() async {
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

const longTitle =
    'Introduction à la biologie moléculaire et à la génétique des populations humaines';
const _longQuestion =
    'Parmi les mécanismes suivants, lequel explique le mieux pourquoi la réplication de l’ADN est dite semi-conservative chez les eucaryotes lors de la phase S du cycle cellulaire ?';
const _longAnswers = [
  'Chaque nouvelle molécule d’ADN conserve un brin parental et synthétise un brin complémentaire neuf',
  'Les deux brins parentaux restent ensemble et une copie entièrement nouvelle est assemblée à côté',
  'Les brins parentaux sont fragmentés puis recombinés aléatoirement avec des fragments néosynthétisés',
  'La molécule parentale est dégradée par des nucléases puis resynthétisée à partir d’ARN messagers',
];
final _now = DateTime(2026, 9, 4);

CollectionListItem fixtureCollection(
  String id,
  String name, {
  int due = 312,
  bool disabled = false,
}) => CollectionListItem(
  id: id,
  name: name,
  description: 'Import CSV',
  icon: 'A',
  totalCards: 640,
  cardsDone: 210,
  dueCards: due,
  color: 0xFF2E7D6B,
  createdAt: _now,
  updatedAt: _now,
  errorCount: 0,
  isDisabled: disabled,
);

final _collections = [
  fixtureCollection('c1', longTitle),
  fixtureCollection('c2', 'Anglais - Vocabulaire', due: 150),
  fixtureCollection('c3', 'Droit constitutionnel', due: 0, disabled: true),
];

DeckListItem _deck(int i, String name, {bool disabled = false}) => DeckListItem(
  id: 'd$i',
  collectionId: 'c1',
  name: name,
  icon: 'A',
  difficulty: DeckDifficulty.values[i % DeckDifficulty.values.length],
  totalCards: 120,
  cardsDone: 80,
  dueCards: disabled ? 0 : 25,
  progress: 80 / 120,
  status: DeckStatus.dues,
  createdAt: _now.add(Duration(minutes: i)),
  updatedAt: _now,
  isDisabled: disabled,
);

final _decks = [
  _deck(0, 'Structure de l’ADN et des chromosomes'),
  _deck(1, 'Transcription et traduction : du gène à la protéine'),
  _deck(2, 'Mutations', disabled: true),
];

StatisticsOverview _stats() => StatisticsOverview(
  streakDays: 12,
  totalReviews: 1840,
  successRate: .78,
  studyDays: 46,
  heatmap: [
    for (var i = 0; i < 14; i++)
      HeatmapCell(label: 'J$i', count: i % 5 * 6, isActive: i % 5 != 0),
  ],
  levelProgress: [
    LevelProgress(level: 0, count: 120, progress: .2),
    LevelProgress(level: 1, count: 300, progress: .5),
  ],
  successTrend: [
    StatisticsTrendPoint(label: '1/9', reviewCount: 30, successRate: .6),
    StatisticsTrendPoint(label: '2/9', reviewCount: 45, successRate: .7),
  ],
  collectionProgress: [
    CollectionStatistics(name: longTitle, reviewCount: 600, successRate: .7),
  ],
  modeProgress: [
    ModeStatistics(
      mode: TestMode.multipleChoice,
      reviewCount: 8,
      successRate: .8,
    ),
  ],
  difficultCards: [
    DifficultCardStatistics(
      question: _longQuestion,
      errorCount: 9,
      reviewCount: 12,
      successRate: .25,
    ),
  ],
);

final _summary = SessionSummary(
  collectionId: 'c1',
  deckId: 'd0',
  deckTitle: longTitle,
  totalCards: 20,
  reviewCounts: const {
    ReviewResult.again: 3,
    ReviewResult.hard: 4,
    ReviewResult.good: 9,
    ReviewResult.easy: 4,
  },
  correctCount: 15,
  incorrectCount: 5,
  duration: const Duration(minutes: 7, seconds: 32),
);

Future<FilePickerResult?> _pickSampleCsv() async {
  const csv =
      'collection;deck;question;correct_answer;wrong_answer_1;wrong_answer_2;wrong_answer_3;hint;explanation;level\n'
      'Biologie;Cellule;Quel organite produit l’ATP ?;La mitochondrie;Le ribosome;Le noyau;Le lysosome;;;1\n'
      ';;;;;;;;;\n';
  final bytes = Uint8List.fromList(utf8.encode(csv));
  return FilePickerResult([
    PlatformFile(name: 'biologie.csv', size: bytes.length, bytes: bytes),
  ]);
}

const _user = User(
  id: 'u1',
  appMetadata: {},
  userMetadata: {'display_name': 'Léa Martin'},
  aud: 'authenticated',
  createdAt: '2026-01-01',
  email: 'lea.martin@example.com',
);

StudyCard fixtureCard(TestMode mode, {bool long = false}) => StudyCard(
  id: 'card-${mode.name}',
  collectionId: 'c1',
  deckId: 'd0',
  question: long
      ? _longQuestion
      : 'Quel organite produit l’essentiel de l’ATP dans la cellule ?',
  correctAnswer: long ? _longAnswers[0] : 'La mitochondrie',
  wrongAnswers: long
      ? _longAnswers.sublist(1)
      : const ['Le ribosome', 'Le noyau', 'L’appareil de Golgi'],
  hint: 'Pense aux brins parentaux.',
  explanation:
      'La mitochondrie réalise la phosphorylation oxydative, principale source d’ATP.',
  currentTestMode: mode,
  allowedTestModes: [mode],
  clozeText: mode == TestMode.cloze
      ? 'La {{mitochondrie}} produit l’ATP grâce à la {{phosphorylation}} oxydative.'
      : null,
  clozeAnswers: mode == TestMode.cloze
      ? const ['mitochondrie', 'phosphorylation']
      : const [],
  clozeWordBank: mode == TestMode.cloze
      ? const ['mitochondrie', 'phosphorylation', 'glycolyse', 'ribosome']
      : const [],
  acceptedAnswers: const [],
  level: 2,
  progressDots: 3,
);

class FakeStudyController extends StudyController {
  FakeStudyController(this._initial)
    : super.fromPersistence(
        random: math.Random(0),
        loadSession:
            ({
              collectionId,
              deckId,
              forcedMode,
              required sessionCardLimit,
            }) async => _initial,
        submitReview:
            ({
              required cardId,
              required reviewResult,
              required wasCorrect,
              required playedMode,
            }) async {},
      );

  final StudySessionState _initial;

  @override
  Future<StudySessionState> load({
    String? collectionId,
    String? deckId,
    TestMode? forcedMode,
    required int sessionCardLimit,
  }) async => _initial;

  @override
  Future<void> submitReviewIdempotent({
    required String reviewId,
    required String cardId,
    required ReviewResult result,
    required bool wasCorrect,
    required TestMode playedMode,
  }) async {}
}

StudySessionState fixtureSession(StudyCard card) => StudySessionState(
  deckTitle: 'Biologie',
  collectionId: 'c1',
  deckId: 'd0',
  cards: [card, card],
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

typedef Interact = Future<void> Function(WidgetTester t, bool long);

class ScreenCase {
  const ScreenCase(
    this.name,
    this.build,
    this.main, {
    this.overrides,
    this.interact,
    this.kind = 'screen',
  });
  final String name;
  final Widget Function(bool long) build;

  /// The primary action (or last content) a user must be able to reach.
  final Finder Function(bool long) main;
  final List<Override> Function()? overrides;
  final Interact? interact;

  /// 'study' cases run the real StudyScreen.
  final String kind;
}

/// Brings [f] on screen even in a lazy list that has not built it yet.
Future<void> revealing(WidgetTester t, Finder f) async {
  for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
    await t.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await t.pump();
  }
  await t.ensureVisible(f.first);
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> tapScrolling(WidgetTester t, Finder f) async {
  await revealing(t, f);
  await t.tap(f.first);
  await t.pump(const Duration(milliseconds: 50));
}

List<Override> _homeOverrides() => [
  homeStatsProvider.overrideWith(
    (ref) => Stream.value(
      const HomeStats(
        streakDays: 12,
        successRate: .82,
        dueCards: 734,
        totalCardsSeen: 2400,
      ),
    ),
  ),
  homeCollectionsProvider.overrideWith((ref, s) => Stream.value(_collections)),
  currentUserProvider.overrideWithValue(null),
];

ScreenCase _study(
  String name,
  TestMode mode,
  Finder Function(bool long) main, {
  Interact? interact,
}) => ScreenCase(
  name,
  (long) => StudyScreen(
    collectionId: 'c1',
    deckId: 'd0',
    forcedMode: mode,
    controller: FakeStudyController(
      fixtureSession(fixtureCard(mode, long: long)),
    ),
  ),
  main,
  interact: interact,
  kind: 'study',
);

Finder _rate(bool _) => find.text('Encore');

String _correct(bool long) => long ? _longAnswers[0] : 'La mitochondrie';
String _wrong(bool long) => long ? _longAnswers[1] : 'Le ribosome';

Future<void> _fillCloze(WidgetTester t, bool long) async {
  for (final word in ['mitochondrie', 'glycolyse']) {
    await tapScrolling(t, find.text('_____'));
    await tapScrolling(t, find.text(word).last);
  }
  await tapScrolling(t, find.text('Valider ma réponse'));
}

List<ScreenCase> screenCases() => [
  ScreenCase(
    'home',
    (_) => const HomeScreen(),
    (_) => find.text('Étudier maintenant'),
    overrides: _homeOverrides,
  ),
  ScreenCase(
    'collection detail',
    (_) => const CollectionDetailScreen(collectionId: 'c1'),
    (_) => find.text('Étudier'),
    overrides: () => [
      collectionProvider(
        'c1',
      ).overrideWith((ref) => Stream.value(_collections.first)),
      collectionDecksProvider('c1').overrideWith((ref) => Stream.value(_decks)),
    ],
  ),
  ScreenCase(
    'stats',
    (_) => const StatisticsScreen(),
    (_) => find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.data ?? '').toLowerCase() == 'cartes les plus difficiles',
    ),
    overrides: () => [
      statisticsOverviewProvider.overrideWith((ref) => Stream.value(_stats())),
    ],
  ),
  ScreenCase(
    'import',
    (_) => ImportScreen(pickFiles: _pickSampleCsv),
    (_) => find.text('Importer un fichier CSV'),
  ),
  ScreenCase(
    'profile',
    (_) => const ProfileScreen(),
    (_) => find.text('Se déconnecter'),
    overrides: () => [
      currentUserProvider.overrideWithValue(_user),
      syncStatusProvider.overrideWith(
        (ref) => Stream.value(
          SyncStatus(
            state: SyncState.idle,
            pendingCount: 0,
            lastSyncedAt: DateTime(2026, 9, 4, 14, 5),
          ),
        ),
      ),
    ],
  ),
  ScreenCase(
    'settings',
    (_) => const SettingsScreen(),
    (_) => find.text('Cartes par session'),
    overrides: () => [currentUserProvider.overrideWithValue(_user)],
  ),
  ScreenCase(
    'auth',
    (_) => const AuthScreen(),
    (_) => find.widgetWithText(FilledButton, 'Se connecter'),
  ),
  ScreenCase(
    'not found',
    (_) => const NotFoundScreen(requestedPath: '/page-inconnue'),
    (_) => find.text('Retour à l’accueil'),
  ),
  ScreenCase(
    'mode sheet',
    (_) => const _SheetOpener(),
    (_) => find.text('QCM'),
  ),
  ScreenCase(
    'session summary',
    (_) => SessionSummaryScreen(summary: _summary),
    (_) => find.text('Retour à la collection'),
  ),
  _study(
    'study qcm',
    TestMode.multipleChoice,
    (long) => find.text(_correct(long)),
  ),
  _study(
    'study qcm answered',
    TestMode.multipleChoice,
    _rate,
    interact: (t, long) => tapScrolling(t, find.text(_wrong(long))),
  ),
  _study(
    'study flashcard front',
    TestMode.classicFlashcard,
    (_) => find.text('Révéler la réponse'),
  ),
  _study(
    'study flashcard back',
    TestMode.classicFlashcard,
    _rate,
    interact: (t, _) => tapScrolling(t, find.text('Révéler la réponse')),
  ),
  _study(
    'study reversed flashcard front',
    TestMode.reversedFlashcard,
    (_) => find.text('Révéler la réponse'),
  ),
  _study(
    'study reversed flashcard back',
    TestMode.reversedFlashcard,
    _rate,
    interact: (t, _) => tapScrolling(t, find.text('Révéler la réponse')),
  ),
  _study('study free text', TestMode.freeText, (_) => find.text('Vérifier')),
  _study(
    'study free text answered',
    TestMode.freeText,
    _rate,
    interact: (t, _) async {
      await t.enterText(find.byType(TextField).first, 'la mitocondrie');
      await t.pump();
      await tapScrolling(t, find.text('Vérifier'));
    },
  ),
  _study('study true/false', TestMode.trueFalse, (_) => find.text('Faux')),
  _study(
    'study true/false answered',
    TestMode.trueFalse,
    _rate,
    interact: (t, _) => tapScrolling(t, find.text('Faux')),
  ),
  _study('study cloze', TestMode.cloze, (_) => find.text('Valider ma réponse')),
  _study('study cloze answered', TestMode.cloze, _rate, interact: _fillCloze),
];

/// Pumps [c] in a real GoRouter (screens call context.go/push), at [size]
/// and [textScale]. Returns after the first frames; callers settle further.
Future<void> pumpCase(
  WidgetTester tester,
  ScreenCase c, {
  Size size = const Size(360, 800),
  double textScale = 1.0,
  bool long = false,
  bool disableAnimations = false,
  bool warmUp = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => c.build(long))],
    errorBuilder: (_, _) => const SizedBox(),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...?c.overrides?.call(),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: AdaptiveTheme(child: child!),
        ),
      ),
    ),
  );
  if (!warmUp) return;
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _SheetOpener extends StatefulWidget {
  const _SheetOpener();
  @override
  State<_SheetOpener> createState() => _SheetOpenerState();
}

class _SheetOpenerState extends State<_SheetOpener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModeSelectionSheet(
        context,
        availability: const StudyModeAvailability(
          total: 40,
          compatible: {
            TestMode.multipleChoice: 40,
            TestMode.classicFlashcard: 40,
            TestMode.reversedFlashcard: 40,
            TestMode.cloze: 12,
            TestMode.freeText: 25,
            TestMode.trueFalse: 0,
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}
