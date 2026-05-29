import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/app/session_controller.dart';
import 'package:memflow/data/local/database.dart';
import 'package:memflow/data/repositories/app_repository.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/card_mode_service.dart';
import 'package:memflow/domain/services/spaced_repetition_service.dart';
import 'package:memflow/domain/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  late AppRepository repository;
  late SessionController controller;
  final now = DateTime(2026, 5, 29, 9, 0);

  setUp(() {
    database = AppDatabase.memory();
    remote = FakeRemoteSource();
    syncService = SyncService(database: database, remoteSource: remote);
    repository = AppRepository(
      database: database,
      spacedRepetitionService: const SpacedRepetitionService(),
      cardModeService: const CardModeService(),
      syncService: syncService,
    );
    controller = SessionController(
      database: database,
      repository: repository,
      syncService: syncService,
      authStateChanges: const Stream<AuthState>.empty(),
    );
  });

  tearDown(() async {
    controller.dispose();
    await database.close();
  });

  Future<void> insertCollection(String id) {
    return database.into(database.collections).insert(
          CollectionsCompanion.insert(
            id: id,
            name: id,
            description: 'desc',
            icon: '📚',
            totalCards: 1,
            masteredPercentage: 0,
            color: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  test('first sign-in claims pre-existing local data', () async {
    await insertCollection('react');

    await controller.reconcileSignIn('user-a');

    expect(await database.readMetaString(kActiveUserIdKey), 'user-a');
    // The local collection was enqueued and pushed up to the account.
    expect(
      remote.pushed.where((r) => r.entityType == SyncEntityType.collection),
      isNotEmpty,
    );
  });

  test('switching account wipes local data and adopts the new owner', () async {
    await insertCollection('react');
    await controller.reconcileSignIn('user-a');

    await controller.reconcileSignIn('user-b');

    expect(await database.readMetaString(kActiveUserIdKey), 'user-b');
    expect(await database.isEmpty(), isTrue);
  });

  test('sign-out clears local user data', () async {
    await insertCollection('react');
    await controller.reconcileSignIn('user-a');

    await controller.reconcileSignOut();

    expect(await database.isEmpty(), isTrue);
    expect(await database.readMetaString(kActiveUserIdKey), isNull);
  });
}
