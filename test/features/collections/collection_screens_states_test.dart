import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/app/providers.dart';
import 'package:memflow/data/local/database.dart';
import 'package:memflow/data/repositories/app_repository.dart';
import 'package:memflow/data/sync/sync_service.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/card_mode_service.dart';
import 'package:memflow/domain/services/spaced_repetition_service.dart';
import 'package:memflow/features/collections/collection_detail_screen.dart';
import 'package:memflow/features/collections/collection_due_cards_screen.dart';
import 'package:memflow/features/collections/deck_cards_screen.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _secret = 'SECRET_EXCEPTION_TEXT';
final _longTitle = 'Titre très long de collection '.padRight(60, 'x');
const _longDescription =
    'Une description assez longue pour passer à la ligne plusieurs fois '
    'sur un petit écran, y compris avec un texte agrandi.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.memory();
  });

  tearDown(() => database.close());

  Future<void> pump(
    WidgetTester tester,
    _FakeRepo repository,
    Widget home, {
    Size size = const Size(360, 800),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  _FakeRepo repo({
    CollectionListItem? collection,
    List<DeckListItem>? decks,
    bool collectionError = false,
    bool decksError = false,
    bool pagesError = false,
  }) => _FakeRepo(
    database: database,
    collection: collection ?? _collection(),
    decks: decks ?? [_deck(0)],
    collectionError: collectionError,
    decksError: decksError,
    pagesError: pagesError,
  );

  const detail = CollectionDetailScreen(collectionId: 'collection-1');

  final sizes = <String, (Size, double)>{
    '320x568': (const Size(320, 568), 1),
    '360x800': (const Size(360, 800), 1),
    '360x800 at 2.0 text scale': (const Size(360, 800), 2),
  };
  for (final entry in sizes.entries) {
    testWidgets('detail renders without exception at ${entry.key}', (
      tester,
    ) async {
      await pump(
        tester,
        repo(
          collection: _collection(
            name: _longTitle,
            description: _longDescription,
          ),
          decks: [
            _deck(0, name: 'Un nom de deck vraiment très long à afficher'),
            _deck(1, name: 'Deck désactivé avec un nom long', disabled: true),
          ],
        ),
        detail,
        size: entry.value.$1,
        textScale: entry.value.$2,
      );
      expect(find.text(_longTitle), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Parcourt toute la page, y compris le bas, sans exception.
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('deck count is singular for one deck', (tester) async {
    await pump(tester, repo(decks: [_deck(0)]), detail);
    expect(find.text('1 deck'), findsOneWidget);
  });

  testWidgets('deck count is plural for several decks', (tester) async {
    await pump(tester, repo(decks: [_deck(0), _deck(1)]), detail);
    expect(find.text('2 decks'), findsOneWidget);
  });

  testWidgets('the FAB never covers the last row', (tester) async {
    await pump(
      tester,
      repo(decks: List.generate(8, _deck)),
      detail,
      size: const Size(360, 640),
    );
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
    }
    final lastRow = tester.getRect(find.byType(OutlinedButton));
    final fab = tester.getRect(find.byType(FloatingActionButton));
    expect(lastRow.bottom, lessThanOrEqualTo(fab.top));
  });

  testWidgets('no decks shows an empty state with an import action', (
    tester,
  ) async {
    await pump(tester, repo(decks: []), detail);
    expect(find.text('Aucun deck'), findsOneWidget);
    expect(find.text('Importer un CSV'), findsOneWidget);
  });

  testWidgets('due line is omitted when there is nothing to review', (
    tester,
  ) async {
    await pump(
      tester,
      repo(decks: [_deck(0, due: 0), _deck(1, due: 3)]),
      detail,
    );
    expect(find.text('0 à revoir'), findsNothing);
    expect(find.text('3 à revoir'), findsOneWidget);
  });

  testWidgets('collection error hides the exception and can retry', (
    tester,
  ) async {
    await pump(tester, repo(collectionError: true), detail);
    expect(find.textContaining(_secret), findsNothing);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.byTooltip('Retour'), findsOneWidget);
  });

  testWidgets('decks error hides the exception and can retry', (tester) async {
    await pump(tester, repo(decksError: true), detail);
    expect(find.textContaining(_secret), findsNothing);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('missing collection offers a way back', (tester) async {
    await pump(
      tester,
      _FakeRepo(database: database, collection: null, decks: const []),
      detail,
    );
    expect(find.text('Collection introuvable'), findsOneWidget);
    expect(find.text("Retour à l'accueil"), findsOneWidget);
  });

  testWidgets('back and menu buttons have tooltips', (tester) async {
    await pump(tester, repo(), detail);
    expect(find.byTooltip('Retour'), findsOneWidget);
    expect(find.byTooltip('Options de la collection'), findsOneWidget);
    expect(find.byTooltip('Options du deck'), findsOneWidget);
  });

  group('due-cards', () {
    const screen = CollectionDueCardsScreen(
      collectionId: 'collection-1',
      collectionName: 'Collection test',
    );

    testWidgets('empty state', (tester) async {
      await pump(tester, repo(), screen);
      expect(find.text('Aucune carte'), findsOneWidget);
      expect(find.byTooltip('Retour'), findsOneWidget);
    });

    testWidgets('error state hides the exception', (tester) async {
      await pump(tester, repo(pagesError: true), screen);
      expect(find.text('Impossible de charger les échéances.'), findsOneWidget);
      expect(find.textContaining(_secret), findsNothing);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });

  group('deck-cards', () {
    const screen = DeckCardsScreen(deckId: 'deck-0', deckName: 'Mon deck');

    testWidgets('empty state', (tester) async {
      await pump(tester, repo(), screen);
      expect(find.text('Ce deck ne contient aucune carte.'), findsOneWidget);
      expect(find.byTooltip('Retour'), findsOneWidget);
    });

    testWidgets('error state hides the exception', (tester) async {
      await pump(tester, repo(pagesError: true), screen);
      expect(find.text('Impossible de charger les cartes.'), findsOneWidget);
      expect(find.textContaining(_secret), findsNothing);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });
}

CollectionListItem _collection({
  String name = 'Collection test',
  String description = 'Import CSV',
}) {
  final now = DateTime(2026, 7, 19);
  return CollectionListItem(
    id: 'collection-1',
    name: name,
    description: description,
    icon: 'C',
    totalCards: 120,
    cardsDone: 24,
    dueCards: 18,
    color: 0xFFDE7935,
    createdAt: now,
    updatedAt: now,
    errorCount: 0,
    isDisabled: false,
  );
}

DeckListItem _deck(
  int index, {
  String? name,
  int due = 3,
  bool disabled = false,
}) {
  final now = DateTime(2026, 7, 19).add(Duration(minutes: index));
  return DeckListItem(
    id: 'deck-$index',
    collectionId: 'collection-1',
    name: name ?? 'Deck $index',
    icon: 'D',
    difficulty: DeckDifficulty.facile,
    totalCards: 10,
    cardsDone: 2,
    dueCards: due,
    progress: 0.2,
    status: DeckStatus.dues,
    createdAt: now,
    updatedAt: now,
    isDisabled: disabled,
  );
}

class _FakeRepo extends AppRepository {
  // ignore: use_super_parameters
  _FakeRepo({
    required this.collection,
    required this.decks,
    required AppDatabase database,
    this.collectionError = false,
    this.decksError = false,
    this.pagesError = false,
  }) : super(
         database: database,
         syncService: SyncService(
           database: database,
           client: SupabaseClient(
             'http://localhost',
             'test-key',
             authOptions: const AuthClientOptions(autoRefreshToken: false),
           ),
         ),
         spacedRepetitionService: const SpacedRepetitionService(),
         cardModeService: const CardModeService(),
       );

  final CollectionListItem? collection;
  final List<DeckListItem> decks;
  final bool collectionError;
  final bool decksError;
  final bool pagesError;

  @override
  Stream<CollectionListItem?> watchCollection(String id) => collectionError
      ? Stream.error(Exception(_secret))
      : Stream.value(collection);

  @override
  Stream<List<DeckListItem>> watchDecksForCollection(String collectionId) =>
      decksError ? Stream.error(Exception(_secret)) : Stream.value(decks);

  @override
  Future<PaginatedSlice<FlashcardDueItem>> fetchDueCardsForCollectionPage({
    required String collectionId,
    required int offset,
    required int limit,
  }) async {
    if (pagesError) throw Exception(_secret);
    return const PaginatedSlice(items: [], totalCount: 0);
  }

  @override
  Future<PaginatedSlice<FlashcardSummary>> fetchFlashcardsForDeckPage({
    required String deckId,
    required int offset,
    required int limit,
  }) async {
    if (pagesError) throw Exception(_secret);
    return const PaginatedSlice(items: [], totalCount: 0);
  }

  @override
  Stream<int> watchDueCardsForCollectionRevision() => const Stream.empty();

  @override
  Stream<int> watchDeckCardsRevision() => const Stream.empty();
}
