import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/data/local/database.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/sync_service.dart';

class FakeRemoteSource implements SyncRemoteSource {
  final pushed = <RemoteSyncRecord>[];
  final pullRecords = <RemoteSyncRecord>[];

  @override
  Future<List<RemoteSyncRecord>> pullChanges({required DateTime since}) async {
    return pullRecords.where((record) => record.updatedAt.isAfter(since)).toList();
  }

  @override
  Future<void> push(RemoteSyncRecord record) async {
    pushed.add(record);
  }
}

void main() {
  late AppDatabase database;
  late FakeRemoteSource remote;
  late SyncService syncService;
  final now = DateTime(2026, 5, 29, 9, 0);

  setUp(() {
    database = AppDatabase.memory();
    remote = FakeRemoteSource();
    syncService = SyncService(database: database, remoteSource: remote);
  });

  tearDown(() async {
    await database.close();
  });

  test('runSync pushes queue entries and clears the queue', () async {
    await syncService.enqueueUpsert(
      SyncEntityType.collection,
      'react',
      {
        'id': 'react',
        'name': 'React & Hooks',
        'description': 'desc',
        'icon': '⚛️',
        'total_cards': 12,
        'mastered_percentage': 0.5,
        'color': 123,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
    );

    await syncService.runSync();

    expect(remote.pushed, hasLength(1));
    expect(await database.pendingSyncEntries(), isEmpty);
  });

  test('runSync applies newer remote records over older local ones', () async {
    await database.into(database.collections).insert(
          CollectionsCompanion.insert(
            id: 'react',
            name: 'React ancien',
            description: 'desc',
            icon: '⚛️',
            totalCards: 10,
            masteredPercentage: 0.2,
            color: 1,
            createdAt: now,
            updatedAt: now.subtract(const Duration(days: 1)),
          ),
        );

    remote.pullRecords.add(
      RemoteSyncRecord(
        entityType: SyncEntityType.collection,
        entityId: 'react',
        payload: {
          'id': 'react',
          'name': 'React & Hooks',
          'description': 'desc',
          'icon': '⚛️',
          'total_cards': 24,
          'mastered_percentage': 0.75,
          'color': 22,
          'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
        updatedAt: now,
      ),
    );

    await syncService.runSync();

    final collection = await (database.select(database.collections)
          ..where((table) => table.id.equals('react')))
        .getSingle();
    expect(collection.name, 'React & Hooks');
    expect(collection.totalCards, 24);
    expect(collection.masteredPercentage, 0.75);
  });

  test('pickWinner keeps local record when it is newer', () {
    final winner = syncService.pickWinner(
      now,
      now.subtract(const Duration(hours: 1)),
    );

    expect(winner, SyncWinner.local);
  });
}
