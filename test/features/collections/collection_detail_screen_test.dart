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
import 'package:memflow/theme/theme_controller.dart';
import 'package:memflow/widgets/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.memory();
  });

  tearDown(() => database.close());

  testWidgets('the entire collection detail uses one scroll view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeAppRepository(
      database: database,
      collection: _collection(),
      decks: List.generate(12, _deck),
    );
    await _pumpScreen(tester, repository);

    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Collection test'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('collection-icon'))),
      const Size(64, 64),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pumpAndSettle();

    expect(find.text('Deck 11'), findsOneWidget);
    expect(find.text('Collection test'), findsNothing);
  });

  testWidgets('a disabled collection blocks study but remains manageable', (
    tester,
  ) async {
    final repository = _FakeAppRepository(
      database: database,
      collection: _collection(isDisabled: true),
      decks: [_deck(0)],
    );
    await _pumpScreen(tester, repository);

    expect(find.text('Désactivée'), findsOneWidget);
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNull,
    );
    expect(tester.widget<DeckCard>(find.byType(DeckCard)).onTap, isNull);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réactiver la collection'));
    await tester.pumpAndSettle();

    expect(repository.updatedCollectionId, 'collection-1');
    expect(repository.updatedDisabledValue, isFalse);
  });

  testWidgets('the collection icon can be selected and persisted', (
    tester,
  ) async {
    final repository = _FakeAppRepository(
      database: database,
      collection: _collection(),
      decks: [_deck(0)],
    );
    await _pumpScreen(tester, repository);

    await tester.tap(find.byKey(const ValueKey('collection-icon')));
    await tester.pumpAndSettle();

    expect(find.text('Choisir une icône'), findsOneWidget);
    expect(find.text('🔢'), findsOneWidget);
    expect(find.text('🛠️'), findsOneWidget);

    await tester.tap(find.text('🧠'));
    await tester.pumpAndSettle();

    expect(repository.updatedIconCollectionId, 'collection-1');
    expect(repository.updatedIcon, '🧠');
  });

  testWidgets('decks can be sorted by import order and alphabetically', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 19);
    final repository = _FakeAppRepository(
      database: database,
      collection: _collection(),
      decks: [
        _customDeck(
          0,
          name: 'Beta',
          createdAt: now.add(const Duration(minutes: 1)),
        ),
        _customDeck(1, name: 'Alpha', createdAt: now),
        _customDeck(
          2,
          name: 'Gamma',
          createdAt: now.add(const Duration(minutes: 2)),
        ),
      ],
    );
    await _pumpScreen(tester, repository);

    expect(_visibleDeckOrder(tester), ['Alpha', 'Beta', 'Gamma']);

    await _selectDeckSort(tester, 'Importation décroissant');
    expect(_visibleDeckOrder(tester), ['Gamma', 'Beta', 'Alpha']);

    await _selectDeckSort(tester, 'Alphabet croissant');
    expect(_visibleDeckOrder(tester), ['Alpha', 'Beta', 'Gamma']);

    await _selectDeckSort(tester, 'Alphabet décroissant');
    expect(_visibleDeckOrder(tester), ['Gamma', 'Beta', 'Alpha']);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeAppRepository repository,
) async {
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const CollectionDetailScreen(collectionId: 'collection-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CollectionListItem _collection({bool isDisabled = false}) {
  final now = DateTime(2026, 7, 19);
  return CollectionListItem(
    id: 'collection-1',
    name: 'Collection test',
    description: 'Import CSV',
    icon: 'C',
    totalCards: 120,
    cardsDone: 24,
    dueCards: 18,
    color: 0xFFDE7935,
    createdAt: now,
    updatedAt: now,
    errorCount: 0,
    isDisabled: isDisabled,
  );
}

DeckListItem _deck(int index) {
  final now = DateTime(2026, 7, 19);
  return _customDeck(
    index,
    name: 'Deck $index',
    createdAt: now.add(Duration(minutes: index)),
  );
}

DeckListItem _customDeck(
  int index, {
  required String name,
  required DateTime createdAt,
}) {
  return DeckListItem(
    id: 'deck-$index',
    collectionId: 'collection-1',
    name: name,
    icon: 'D',
    difficulty: DeckDifficulty.facile,
    totalCards: 10,
    cardsDone: 2,
    dueCards: 3,
    progress: 0.2,
    status: DeckStatus.dues,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

Future<void> _selectDeckSort(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Trier les decks'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

List<String> _visibleDeckOrder(WidgetTester tester) {
  final names = ['Alpha', 'Beta', 'Gamma'];
  final positioned = [
    for (final name in names) (name, tester.getTopLeft(find.text(name)).dy),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final item in positioned) item.$1];
}

class _FakeAppRepository extends AppRepository {
  // `database` ne peut pas être un super paramètre : il est aussi lu dans la
  // liste d'initialisation pour construire le service de synchronisation.
  // ignore: use_super_parameters
  _FakeAppRepository({
    required this.collection,
    required this.decks,
    required AppDatabase database,
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

  final CollectionListItem collection;
  final List<DeckListItem> decks;
  String? updatedCollectionId;
  bool? updatedDisabledValue;
  String? updatedIconCollectionId;
  String? updatedIcon;

  @override
  Stream<CollectionListItem?> watchCollection(String id) {
    return Stream.value(collection);
  }

  @override
  Stream<List<DeckListItem>> watchDecksForCollection(String collectionId) {
    return Stream.value(decks);
  }

  @override
  Future<void> setCollectionDisabled(
    String collectionId,
    bool isDisabled,
  ) async {
    updatedCollectionId = collectionId;
    updatedDisabledValue = isDisabled;
  }

  @override
  Future<void> setCollectionIcon(String collectionId, String icon) async {
    updatedIconCollectionId = collectionId;
    updatedIcon = icon;
  }
}
