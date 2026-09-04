import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/data/local/database.dart';
import 'package:memflow/data/sync/sync_service.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;

  setUp(() => database = AppDatabase.memory());
  tearDown(() => database.close());

  group('retour de la connectivité', () {
    test('déclenche immédiatement une synchronisation', () async {
      final networkChanges = StreamController<bool>();
      addTearDown(networkChanges.close);
      final service = _CountingSyncService(
        database: database,
        client: SupabaseClient('http://localhost', 'test-key'),
        networkChanges: networkChanges.stream,
      );
      addTearDown(service.dispose);

      await service.startFor('user-a');
      expect(service.syncCalls, 1);

      networkChanges.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(service.syncCalls, 2);
    });

    test('ignore la perte de réseau et ne double pas l’écoute', () async {
      final networkChanges = StreamController<bool>();
      addTearDown(networkChanges.close);
      final service = _CountingSyncService(
        database: database,
        client: SupabaseClient('http://localhost', 'test-key'),
        networkChanges: networkChanges.stream,
      );
      addTearDown(service.dispose);

      await service.startFor('user-a');
      await service.startFor('user-a');
      networkChanges.add(false);
      networkChanges.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(service.syncCalls, 3);
    });
  });

  Future<void> seedCollection(String id) {
    return database
        .into(database.collections)
        .insertOnConflictUpdate(
          CollectionsCompanion.insert(
            id: id,
            name: 'Collection $id',
            description: '',
            icon: '📚',
            color: 0xFFDE7935,
            createdAt: DateTime(2026, 8, 1),
            updatedAt: DateTime(2026, 8, 1),
          ),
        );
  }

  Future<void> seedDeck(String id, String collectionId) {
    return database
        .into(database.decks)
        .insertOnConflictUpdate(
          DecksCompanion.insert(
            id: id,
            collectionId: collectionId,
            name: 'Deck $id',
            icon: '🗂️',
            difficulty: DeckDifficulty.facile,
            createdAt: DateTime(2026, 8, 1),
            updatedAt: DateTime(2026, 8, 1),
          ),
        );
  }

  group('propriété de la base locale', () {
    test('changer de compte repart d\'une base vide', () async {
      await database.adoptOwner('user-a');
      await seedCollection('c1');

      final wiped = await database.adoptOwner('user-b');

      expect(wiped, isTrue);
      expect(await database.select(database.collections).get(), isEmpty);
      expect(await database.readMetaString(AppDatabase.ownerKey), 'user-b');
    });

    test('retrouver le même compte conserve les données', () async {
      await database.adoptOwner('user-a');
      await seedCollection('c1');

      final wiped = await database.adoptOwner('user-a');

      expect(wiped, isFalse);
      expect(await database.select(database.collections).get(), hasLength(1));
    });
  });

  group('file de synchronisation', () {
    test('une suppression remplace un envoi non parti', () async {
      await database.enqueueSync(
        entityType: SyncEntityType.flashcard,
        entityId: 'card-1',
        operation: SyncOperation.upsert,
      );
      await database.enqueueSync(
        entityType: SyncEntityType.flashcard,
        entityId: 'card-1',
        operation: SyncOperation.delete,
      );

      final pending = await database.pendingSyncEntries();

      expect(pending, hasLength(1));
      expect(pending.single.operation, SyncOperation.delete);
    });

    test('deux entités distinctes gardent deux intentions', () async {
      await database.enqueueSync(
        entityType: SyncEntityType.flashcard,
        entityId: 'card-1',
        operation: SyncOperation.upsert,
      );
      await database.enqueueSync(
        entityType: SyncEntityType.deck,
        entityId: 'card-1',
        operation: SyncOperation.upsert,
      );

      expect(await database.pendingSyncEntries(), hasLength(2));
    });
  });

  test('la réconciliation nettoie les lignes devenues orphelines', () async {
    await seedCollection('c1');
    await seedDeck('d1', 'c1');
    await database
        .into(database.flashcards)
        .insertOnConflictUpdate(
          FlashcardsCompanion.insert(
            id: 'f1',
            collectionId: 'c1',
            deckId: 'd1',
            question: 'Q',
            correctAnswer: 'R',
            wrongAnswers: const ['A'],
            currentTestMode: TestMode.multipleChoice,
            allowedTestModes: const [TestMode.multipleChoice],
            modeHistory: const [TestMode.multipleChoice],
            clozeAnswers: const [],
            clozeWordBank: const [],
            acceptedAnswers: const [],
            level: 1,
            tags: const [],
            dueAt: DateTime(2026, 8, 1),
            intervalDays: 0,
            easeFactor: 2.5,
            repetitions: 0,
            lapses: 0,
            mastered: false,
            createdAt: DateTime(2026, 8, 1),
            updatedAt: DateTime(2026, 8, 1),
          ),
        );

    // Un autre appareil a supprimé la collection : la réconciliation ne voit
    // disparaître que son identifiant, la cascade est à refaire localement.
    await (database.delete(
      database.collections,
    )..where((table) => table.id.equals('c1'))).go();
    await database.deleteOrphans();

    expect(await database.select(database.decks).get(), isEmpty);
    expect(await database.select(database.flashcards).get(), isEmpty);
  });

  group('sérialisation vers Supabase', () {
    test('une collection produit exactement les colonnes distantes', () async {
      await seedCollection('c1');
      final row = (await database.select(database.collections).get()).single;

      expect(SyncService.collectionPayload(row).keys, {
        'id',
        'name',
        'description',
        'icon',
        'color',
        'is_disabled',
        'created_at',
        'updated_at',
      });
    });

    test('un deck ne porte plus les colonnes d\'agrégat', () async {
      await seedCollection('c1');
      await seedDeck('d1', 'c1');
      final row = (await database.select(database.decks).get()).single;

      final payload = SyncService.deckPayload(row);

      expect(payload.keys, {
        'id',
        'collection_id',
        'name',
        'icon',
        'difficulty',
        'is_disabled',
        'created_at',
        'updated_at',
      });
      expect(payload.containsKey('total_cards'), isFalse);
      expect(payload.containsKey('status'), isFalse);
    });

    test('les dates partent en UTC', () async {
      await seedCollection('c1');
      final row = (await database.select(database.collections).get()).single;

      final payload = SyncService.collectionPayload(row);

      expect(payload['created_at'], endsWith('Z'));
      expect(payload['updated_at'], endsWith('Z'));
    });
  });
}

class _CountingSyncService extends SyncService {
  _CountingSyncService({
    required super.database,
    required super.client,
    required super.networkChanges,
  });

  var syncCalls = 0;

  @override
  Future<void> syncNow() async {
    syncCalls++;
  }
}
