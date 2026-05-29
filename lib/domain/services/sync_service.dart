import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/local/database.dart';
import '../models/models.dart';

abstract class SyncRemoteSource {
  Future<void> push(RemoteSyncRecord record);

  Future<void> deleteEntity(SyncEntityType entityType, String entityId);

  Future<List<RemoteSyncRecord>> pullChanges({
    required DateTime since,
  });
}

class SupabaseSyncRemoteSource implements SyncRemoteSource {
  SupabaseSyncRemoteSource(this._client);

  final SupabaseClient _client;

  static const _tableByEntity = {
    SyncEntityType.collection: 'collections',
    SyncEntityType.deck: 'decks',
    SyncEntityType.flashcard: 'flashcards',
    SyncEntityType.reviewLog: 'review_logs',
  };
  static const _cursorColumnByEntity = {
    SyncEntityType.collection: 'updated_at',
    SyncEntityType.deck: 'updated_at',
    SyncEntityType.flashcard: 'updated_at',
    SyncEntityType.reviewLog: 'created_at',
  };

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Cannot sync without an authenticated user.');
    }
    return id;
  }

  @override
  Future<void> push(RemoteSyncRecord record) async {
    final table = _tableByEntity[record.entityType]!;
    // Stamp ownership so the row satisfies the per-user RLS policy. Enqueued
    // payloads stay user-agnostic; ownership is resolved at push time.
    final payload = {...record.payload, 'user_id': _userId};
    await _client.from(table).upsert(payload);
  }

  @override
  Future<void> deleteEntity(SyncEntityType entityType, String entityId) async {
    final table = _tableByEntity[entityType]!;
    await _client.from(table).delete().eq('id', entityId).eq('user_id', _userId);
  }

  @override
  Future<List<RemoteSyncRecord>> pullChanges({required DateTime since}) async {
    final all = <RemoteSyncRecord>[];
    final userId = _userId;

    for (final entry in _tableByEntity.entries) {
      final cursorColumn = _cursorColumnByEntity[entry.key]!;
      // RLS already restricts rows to the current user; the explicit filter
      // keeps the query robust and self-documenting.
      final rows = await _client
          .from(entry.value)
          .select()
          .eq('user_id', userId)
          .gt(cursorColumn, since.toUtc().toIso8601String());
      for (final row in rows) {
        final payload = Map<String, dynamic>.from(row as Map);
        all.add(
          RemoteSyncRecord(
            entityType: entry.key,
            entityId: payload['id'] as String,
            payload: payload,
            updatedAt: DateTime.parse(payload[cursorColumn] as String),
          ),
        );
      }
    }

    all.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return all;
  }
}

class SyncService {
  SyncService({
    required AppDatabase database,
    required SyncRemoteSource? remoteSource,
  })  : _database = database,
        _remoteSource = remoteSource;

  final AppDatabase _database;
  final SyncRemoteSource? _remoteSource;
  Future<void>? _activeSync;

  bool get isEnabled => _remoteSource != null;

  Future<void> enqueueUpsert(
    SyncEntityType entityType,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    await _database.upsertSyncQueueEntry(
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperation.upsert,
      payloadJson: jsonEncode(payload),
    );
  }

  Future<void> enqueueDelete(SyncEntityType entityType, String entityId) async {
    await _database.upsertSyncQueueEntry(
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperation.delete,
      payloadJson: '{}',
    );
  }

  /// Resets the pull cursor so the next [runSync] re-fetches all remote data.
  Future<void> resetSyncCursor() => _database.deleteMeta('last_pull_at');

  void scheduleSync() {
    if (_remoteSource == null) {
      return;
    }

    unawaited(runSync().catchError((Object error, StackTrace stackTrace) {}));
  }

  Future<void> runSync() {
    final activeSync = _activeSync;
    if (activeSync != null) {
      return activeSync;
    }

    late final Future<void> syncFuture;
    syncFuture = _runSyncInternal().whenComplete(() {
      if (identical(_activeSync, syncFuture)) {
        _activeSync = null;
      }
    });
    _activeSync = syncFuture;
    return syncFuture;
  }

  Future<void> _runSyncInternal() async {
    if (_remoteSource == null) {
      return;
    }

    final queue = await _database.pendingSyncEntries();
    for (final entry in queue) {
      try {
        switch (entry.operation) {
          case SyncOperation.upsert:
            final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
            final record = RemoteSyncRecord(
              entityType: entry.entityType,
              entityId: entry.entityId,
              payload: payload,
              updatedAt: entry.updatedAt,
            );
            await _remoteSource.push(record);
          case SyncOperation.delete:
            await _remoteSource.deleteEntity(entry.entityType, entry.entityId);
        }
        await _database.deleteSyncQueueEntry(entry.id);
      } catch (_) {
        await _database.incrementSyncQueueAttempts(entry.id);
      }
    }

    final since = await _database.readMetaDateTime('last_pull_at') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final remoteChanges = await _remoteSource.pullChanges(since: since);
    for (final record in remoteChanges) {
      try {
        final localUpdatedAt = await _database.readEntityUpdatedAt(
          record.entityType,
          record.entityId,
        );
        if (localUpdatedAt == null ||
            pickWinner(localUpdatedAt, record.updatedAt) == SyncWinner.remote) {
          await _database.applyRemoteRecord(record);
        }
      } catch (_) {
        // Skip records that fail to apply rather than aborting the whole pull.
      }
    }

    await _database.writeMetaDateTime('last_pull_at', DateTime.now().toUtc());
  }

  SyncWinner pickWinner(DateTime localUpdatedAt, DateTime remoteUpdatedAt) {
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      return SyncWinner.remote;
    }
    return SyncWinner.local;
  }
}

enum SyncWinner { local, remote }
