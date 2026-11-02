// Visual review harness: renders screens to PNG and logs layout exceptions.
// Off by default. Run with:
//   flutter test --dart-define=VISUAL_OUT=before test/visual/render_screens_test.dart
// Output: build/visual/<label>/<state>__<viewport>.png + report.txt
// Emoji render as missing glyphs (no emoji font in tests): expected.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/card_mode_service.dart';
import 'package:memflow/features/auth/auth_screen.dart';
import 'package:memflow/data/local/database.dart';
import 'package:memflow/data/repositories/app_repository.dart';
import 'package:memflow/domain/services/spaced_repetition_service.dart';
import 'package:memflow/features/collections/collection_detail_screen.dart';
import 'package:memflow/features/collections/collection_due_cards_screen.dart';
import 'package:memflow/features/collections/deck_cards_screen.dart';
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
import 'package:memflow/app/providers.dart';
import 'package:memflow/app/router.dart' show TabShell;
import 'package:memflow/data/sync/sync_service.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient, User;

const _label = String.fromEnvironment('VISUAL_OUT');

// ---------------------------------------------------------------------------
// Fake data (French, realistic). Edit here only.
// ---------------------------------------------------------------------------
const _longTitle =
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

CollectionListItem _col(
  String id,
  String name,
  String icon,
  int total,
  int done,
  int due,
  int color, {
  bool disabled = false,
}) => CollectionListItem(
  id: id,
  name: name,
  description: 'Import CSV',
  icon: icon,
  totalCards: total,
  cardsDone: done,
  dueCards: due,
  color: color,
  createdAt: _now,
  updatedAt: _now,
  errorCount: 0,
  isDisabled: disabled,
);

final _collections = [
  _col('c1', _longTitle, '🧬', 640, 210, 312, 0xFF2E7D6B),
  _col('c2', 'Anglais - Vocabulaire', '🇬🇧', 420, 300, 150, 0xFFDE7935),
  _col('c3', 'React', '⚛️', 180, 90, 72, 0xFF3F6FD8),
  _col('c4', 'Histoire de France', '🏰', 300, 40, 200, 0xFF9C4A8B),
  _col(
    'c5',
    'Droit constitutionnel',
    '⚖️',
    90,
    10,
    0,
    0xFF7A7A7A,
    disabled: true,
  ),
];

DeckListItem _deck(
  int i,
  String name,
  int total,
  int done,
  int due, {
  bool disabled = false,
}) => DeckListItem(
  id: 'd$i',
  collectionId: 'c1',
  name: name,
  icon: '📘',
  difficulty: DeckDifficulty.values[i % DeckDifficulty.values.length],
  totalCards: total,
  cardsDone: done,
  dueCards: due,
  progress: total == 0 ? 0 : done / total,
  status: due > 0 ? DeckStatus.dues : DeckStatus.values.first,
  createdAt: _now.add(Duration(minutes: i)),
  updatedAt: _now,
  isDisabled: disabled,
);

final _decks = [
  _deck(0, 'Structure de l’ADN et des chromosomes', 120, 80, 25),
  _deck(1, 'Réplication', 90, 30, 40),
  _deck(2, 'Transcription et traduction : du gène à la protéine', 150, 60, 80),
  _deck(3, 'Mutations', 60, 0, 0, disabled: true),
  _deck(4, 'Génétique des populations', 220, 40, 167),
];

const _homeStats = HomeStats(
  streakDays: 12,
  successRate: .82,
  dueCards: 734,
  totalCardsSeen: 2400,
);
const _homeStatsZero = HomeStats(
  streakDays: 3,
  successRate: .9,
  dueCards: 0,
  totalCardsSeen: 400,
);

StudyCard _card(
  TestMode mode, {
  String question =
      'Quel organite produit l’essentiel de l’ATP dans la cellule ?',
  String answer = 'La mitochondrie',
  List<String> wrong = const ['Le ribosome', 'Le noyau', 'L’appareil de Golgi'],
  String? explanation =
      'La mitochondrie réalise la phosphorylation oxydative, principale source d’ATP.',
  String? hint,
}) => StudyCard(
  id: 'card-${mode.name}',
  collectionId: 'c1',
  deckId: 'd0',
  question: question,
  correctAnswer: answer,
  wrongAnswers: wrong,
  hint: hint,
  explanation: explanation,
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
);

final _statsFull = StatisticsOverview(
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
    LevelProgress(level: 2, count: 200, progress: .35),
    LevelProgress(level: 3, count: 90, progress: .15),
  ],
  successTrend: [
    StatisticsTrendPoint(label: '1/9', reviewCount: 30, successRate: .6),
    StatisticsTrendPoint(label: '2/9', reviewCount: 45, successRate: .7),
    StatisticsTrendPoint(label: '3/9', reviewCount: 20, successRate: .55),
    StatisticsTrendPoint(label: '4/9', reviewCount: 60, successRate: .85),
  ],
  collectionProgress: [
    CollectionStatistics(name: _longTitle, reviewCount: 600, successRate: .7),
    CollectionStatistics(
      name: 'Anglais - Vocabulaire',
      reviewCount: 900,
      successRate: .88,
    ),
    CollectionStatistics(name: 'React', reviewCount: 340, successRate: .64),
  ],
  modeProgress: [
    ModeStatistics(
      mode: TestMode.multipleChoice,
      reviewCount: 800,
      successRate: .82,
    ),
    ModeStatistics(mode: TestMode.freeText, reviewCount: 300, successRate: .55),
    ModeStatistics(mode: TestMode.trueFalse, reviewCount: 200, successRate: .9),
    ModeStatistics(mode: TestMode.cloze, reviewCount: 150, successRate: .6),
  ],
  difficultCards: [
    DifficultCardStatistics(
      question: _longQuestion,
      errorCount: 9,
      reviewCount: 12,
      successRate: .25,
    ),
    DifficultCardStatistics(
      question: 'Que signifie « idempotent » ?',
      errorCount: 4,
      reviewCount: 10,
      successRate: .6,
    ),
  ],
);

StatisticsOverview _statsEmpty() => StatisticsOverview(
  streakDays: 0,
  totalReviews: 0,
  successRate: 0,
  studyDays: 0,
  heatmap: [
    for (var i = 0; i < 35; i++)
      HeatmapCell(label: 'J$i', count: 0, isActive: false),
  ],
  levelProgress: const [],
  successTrend: [
    for (var i = 1; i <= 7; i++)
      StatisticsTrendPoint(label: '$i/9', reviewCount: 0, successRate: 0),
  ],
  collectionProgress: const [],
  modeProgress: const [],
  difficultCards: const [],
);

final _summary = SessionSummary(
  collectionId: 'c1',
  deckId: 'd0',
  deckTitle: _longTitle,
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

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------
/// Deux cartes valides et une ligne invalide, pour l'état de prévisualisation.
Future<FilePickerResult?> _pickSampleCsv() async {
  const csv =
      'collection;deck;question;correct_answer;wrong_answer_1;wrong_answer_2;wrong_answer_3;hint;explanation;level\n'
      'Biologie;Cellule;Quel organite produit l’ATP ?;La mitochondrie;Le ribosome;Le noyau;Le lysosome;;;1\n'
      'Biologie;Cellule;Où a lieu la transcription ?;Le noyau;Le cytoplasme;Le ribosome;La membrane;;;1\n'
      ';;;;;;;;;\n'
      'Biologie;;Ligne sans deck;;;;;;;1\n';
  final bytes = Uint8List.fromList(utf8.encode(csv));
  return FilePickerResult([
    PlatformFile(
      name: 'biologie_cellule.csv',
      size: bytes.length,
      bytes: bytes,
    ),
  ]);
}

final _signedInUser = User(
  id: 'visual-user',
  appMetadata: const {},
  userMetadata: const {
    'display_name': 'Léa Martin',
    'adult_attested_at': '2026-11-02T00:00:00Z',
    'accepted_terms_version': '2026-11-02',
  },
  aud: 'authenticated',
  createdAt: '2026-01-01',
  email: 'lea.martin@example.com',
);

typedef _Interact = Future<void> Function(WidgetTester t);
typedef _Overrides = List<Override> Function();

class _State {
  _State(
    this.name,
    this.screen, {
    this.overrides,
    this.interact,
    this.route = '/',
    this.shell = false,
  });
  final String name;
  final Widget Function() screen;
  final _Overrides? overrides;
  final _Interact? interact;
  final String route;
  final bool shell; // wrap in the real TabShell (nav bar, Home selected)
}

const _viewports = <(String, Size, double)>[
  ('phone', Size(360, 800), 1.0),
  ('small', Size(320, 568), 1.0),
  ('phone_large_text', Size(360, 800), 2.0),
  ('tall', Size(360, 2400), 1.0),
  ('tablet_portrait', Size(880, 1408), 1.0),
  // Taille de police système réelle de la tablette du propriétaire.
  ('tablet_device', Size(880, 1408), 1.15),
  ('tablet_device_landscape', Size(1408, 880), 1.15),
  ('tablet_landscape', Size(1408, 880), 1.0),
  ('tablet_portrait_large_text', Size(880, 1408), 2.0),
  ('tablet_narrow', Size(600, 960), 1.0),
];

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

List<Override> _homeOverrides(
  HomeStats stats,
  List<CollectionListItem> items,
) => [
  homeStatsProvider.overrideWith((ref) => Stream.value(stats)),
  homeCollectionsProvider.overrideWith((ref, s) => Stream.value(items)),
  currentUserProvider.overrideWithValue(null),
];

Future<void> _tapText(WidgetTester t, String text) => _tap(t, find.text(text));

// Drags the page up until the target is built (small viewports).
Future<void> _tap(WidgetTester t, Finder f) async {
  for (var i = 0; i < 20 && f.evaluate().isEmpty; i++) {
    await t.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await t.pump();
  }
  await t.ensureVisible(f.first);
  await t.tap(f.first);
}

_State _study(
  String name,
  TestMode mode,
  StudyCard card, {
  _Interact? interact,
}) => _State(
  name,
  () => StudyScreen(
    collectionId: 'c1',
    deckId: 'd0',
    forcedMode: mode,
    controller: _FakeStudyController(
      StudySessionState(
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
      ),
    ),
  ),
  interact: interact,
);

List<_State> _states() => [
  _State(
    'home_data',
    () => const HomeScreen(),
    overrides: () => _homeOverrides(_homeStats, _collections),
  ),
  _State(
    'tab_shell',
    () => const HomeScreen(),
    shell: true,
    overrides: () => _homeOverrides(_homeStats, _collections),
  ),
  _State(
    'home_empty',
    () => const HomeScreen(),
    overrides: () => _homeOverrides(_homeStats, const []),
  ),
  _State(
    'home_zero_due',
    () => const HomeScreen(),
    overrides: () => _homeOverrides(_homeStatsZero, _collections),
  ),
  _State(
    'collection_detail',
    () => const CollectionDetailScreen(collectionId: 'c1'),
    overrides: () => [
      collectionProvider(
        'c1',
      ).overrideWith((ref) => Stream.value(_collections.first)),
      collectionDecksProvider('c1').overrideWith((ref) => Stream.value(_decks)),
    ],
  ),
  _State(
    'due_cards',
    () => const CollectionDueCardsScreen(
      collectionId: 'c1',
      collectionName: _longTitle,
    ),
    overrides: () => [appRepositoryProvider.overrideWithValue(_PagesRepo())],
  ),
  _State(
    'deck_cards',
    () => const DeckCardsScreen(deckId: 'd0', deckName: 'Génétique'),
    overrides: () => [appRepositoryProvider.overrideWithValue(_PagesRepo())],
  ),
  _State(
    'mode_sheet',
    () => const _SheetOpener(),
    // Mutations mode "Vrai/Faux" has 0 compatible cards.
  ),
  _study('study_mcq', TestMode.multipleChoice, _card(TestMode.multipleChoice)),
  _study(
    'study_mcq_answered',
    TestMode.multipleChoice,
    _card(TestMode.multipleChoice),
    interact: (t) => _tapText(t, 'Le ribosome'),
  ),
  _study(
    'study_mcq_long',
    TestMode.multipleChoice,
    _card(
      TestMode.multipleChoice,
      question: _longQuestion,
      answer: _longAnswers[0],
      wrong: _longAnswers.sublist(1),
    ),
  ),
  _study(
    'study_flash',
    TestMode.classicFlashcard,
    _card(TestMode.classicFlashcard),
  ),
  _study(
    'study_flash_back',
    TestMode.classicFlashcard,
    _card(TestMode.classicFlashcard),
    interact: (t) => _tapText(t, 'Révéler la réponse'),
  ),
  _study(
    'study_flash_long',
    TestMode.classicFlashcard,
    _card(
      TestMode.classicFlashcard,
      question: _longQuestion,
      answer: _longAnswers[0],
      hint: 'Pense aux brins parentaux.',
    ),
  ),
  _study(
    'study_flash_rev',
    TestMode.reversedFlashcard,
    _card(TestMode.reversedFlashcard),
  ),
  _study('study_free', TestMode.freeText, _card(TestMode.freeText)),
  _study(
    'study_free_submitted',
    TestMode.freeText,
    _card(TestMode.freeText),
    interact: (t) async {
      await t.enterText(find.byType(TextField).first, 'la mitocondrie');
      await t.pump();
      await t.tap(find.byType(FilledButton).first);
    },
  ),
  _study('study_tf', TestMode.trueFalse, _card(TestMode.trueFalse)),
  _study(
    'study_tf_answered',
    TestMode.trueFalse,
    _card(TestMode.trueFalse),
    interact: (t) => _tapText(t, 'Faux'),
  ),
  _study('study_cloze', TestMode.cloze, _card(TestMode.cloze)),
  _study(
    'study_cloze_submitted',
    TestMode.cloze,
    _card(TestMode.cloze),
    interact: (t) async {
      await _tap(t, find.text('_____'));
      await t.pump();
      await _tap(t, find.text('mitochondrie').last);
      await t.pump();
      await _tap(t, find.text('_____'));
      await t.pump();
      await _tap(t, find.text('glycolyse'));
      await t.pump();
      await _tapText(t, 'Valider ma réponse');
    },
  ),
  _State('session_summary', () => SessionSummaryScreen(summary: _summary)),
  _State(
    'stats_data',
    () => const StatisticsScreen(),
    route: '/stats',
    overrides: () => [
      statisticsOverviewProvider.overrideWith(
        (ref) => Stream.value(_statsFull),
      ),
    ],
  ),
  _State(
    'stats_empty',
    () => const StatisticsScreen(),
    route: '/stats',
    overrides: () => [
      statisticsOverviewProvider.overrideWith(
        (ref) => Stream.value(_statsEmpty()),
      ),
    ],
  ),
  _State('import_empty', () => const ImportScreen(), route: '/import'),
  _State(
    'import_preview',
    () => ImportScreen(pickFiles: _pickSampleCsv),
    route: '/import',
    interact: (t) => _tapText(t, 'Importer un fichier CSV'),
  ),
  _State(
    'profile',
    () => const ProfileScreen(),
    route: '/profile',
    overrides: () => [
      currentUserProvider.overrideWithValue(_signedInUser),
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
  _State(
    'settings',
    () => const SettingsScreen(),
    overrides: () => [currentUserProvider.overrideWithValue(_signedInUser)],
  ),
  _State('auth', () => const AuthScreen()),
  _State(
    'not_found',
    () => const NotFoundScreen(requestedPath: '/page-inconnue'),
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final report = <String>[];
  late Directory outDir;

  setUpAll(() async {
    if (_label.isEmpty) return;
    await _loadFonts();
    outDir = Directory('build/visual/$_label')..createSync(recursive: true);
  });

  tearDownAll(() {
    if (_label.isEmpty) return;
    File(
      '${outDir.path}/report.txt',
    ).writeAsStringSync('${report.join('\n')}\n');
  });

  for (final state in _states()) {
    testWidgets('render ${state.name}', (tester) async {
      // Le mode test dessine les ombres en trait noir plein : on les rend
      // vraiment pour que les captures correspondent à l'app.
      debugDisableShadows = false;
      for (final (vpName, size, textScale) in _viewports) {
        final line = '${state.name}__$vpName';
        String? problem;
        void note(Object? e) {
          problem ??= e.toString().split('\n').first;
        }

        // Own onError so every exception is seen (takeException wraps
        // multiple ones in an unhelpful summary). Restored by the binding.
        var errorCount = 0;
        FlutterError.onError = (details) {
          errorCount++;
          note(details.exception);
        };
        void drain() {
          tester.takeException();
        }

        tester.view.devicePixelRatio = 2;
        tester.view.physicalSize = size * 2;
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final key = GlobalKey();
        final router = GoRouter(
          initialLocation: state.route,
          routes: [
            if (state.shell)
              StatefulShellRoute.indexedStack(
                builder: (_, _, shell) => TabShell(navigationShell: shell),
                branches: [
                  StatefulShellBranch(
                    routes: [
                      GoRoute(path: '/', builder: (_, _) => state.screen()),
                    ],
                  ),
                  for (final path in ['/stats', '/import', '/profile'])
                    StatefulShellBranch(
                      routes: [
                        GoRoute(
                          path: path,
                          builder: (_, _) => const SizedBox(),
                        ),
                      ],
                    ),
                ],
              )
            else
              GoRoute(path: state.route, builder: (_, _) => state.screen()),
          ],
          errorBuilder: (_, _) => const SizedBox(),
        );
        try {
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: ProviderScope(
                key: UniqueKey(),
                overrides: [
                  sharedPreferencesProvider.overrideWithValue(prefs),
                  ...?state.overrides?.call(),
                ],
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light(),
                  routerConfig: router,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(textScale)),
                    child: AdaptiveTheme(child: child!),
                  ),
                ),
              ),
            ),
          );
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          drain();
          if (state.interact != null) {
            try {
              await state.interact!(tester);
            } catch (e) {
              note('INTERACT FAILED: $e');
            }
            // Laisse finir l'ondulation et le défilement vers le feedback.
            for (var i = 0; i < 15; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            drain();
          }
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(key),
            );
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '${outDir.path}/$line.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        } catch (e) {
          note('HARNESS: $e');
          tester.takeException();
        }
        report.add(
          '$line: ${problem == null ? 'OK' : '$problem${errorCount > 1 ? ' (+${errorCount - 1} more)' : ''}'}',
        );
        router.dispose();
        // Tear down the tree so the next viewport starts clean.
        await tester.pumpWidget(const SizedBox());
        tester.takeException();
      }
      debugDisableShadows = true;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }, skip: _label.isEmpty);
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

class _FakeStudyController extends StudyController {
  _FakeStudyController(this._initial)
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

// Dépôt minimal pour les listes paginées (échéances, cartes d'un deck).
class _PagesRepo extends AppRepository {
  _PagesRepo()
    : super(
        database: AppDatabase.memory(),
        syncService: SyncService(
          database: AppDatabase.memory(),
          client: SupabaseClient(
            'http://localhost',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        ),
        spacedRepetitionService: const SpacedRepetitionService(),
        cardModeService: const CardModeService(),
      );

  static const _questions = [
    'Quel organite produit l’essentiel de l’ATP dans la cellule eucaryote ?',
    'Que signifie « semi-conservative » pour la réplication de l’ADN ?',
    'Définis la glycolyse en une phrase.',
    'Quelle enzyme relie les fragments d’Okazaki ?',
    'Où a lieu la traduction de l’ARN messager ?',
    'Quelle est la différence entre un allèle dominant et récessif ?',
  ];

  @override
  Future<PaginatedSlice<FlashcardDueItem>> fetchDueCardsForCollectionPage({
    required String collectionId,
    required int offset,
    required int limit,
  }) async => PaginatedSlice(
    items: [
      for (var i = 0; i < _questions.length; i++)
        FlashcardDueItem(
          id: 'q$i',
          deckId: 'd$i',
          deckName: 'Biologie cellulaire',
          question: _questions[i],
          dueAt: _now.add(Duration(days: i)),
          isDueNow: i < 2,
        ),
    ],
    totalCount: _questions.length,
  );

  @override
  Future<PaginatedSlice<FlashcardSummary>> fetchFlashcardsForDeckPage({
    required String deckId,
    required int offset,
    required int limit,
  }) async => PaginatedSlice(
    items: [
      for (var i = 0; i < _questions.length; i++)
        FlashcardSummary(
          id: 'q$i',
          deckId: deckId,
          collectionId: 'c1',
          question: _questions[i],
          correctAnswer:
              'La mitochondrie, grâce à la phosphorylation oxydative.',
        ),
    ],
    totalCount: _questions.length,
  );

  @override
  Stream<int> watchDueCardsForCollectionRevision() => const Stream.empty();

  @override
  Stream<int> watchDeckCardsRevision() => const Stream.empty();
}
