import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/models.dart';
import '../local/database.dart';

enum SyncState { idle, syncing, offline, error }

enum SyncFailureKind { network, server, unknown }

class SyncStatus {
  const SyncStatus({
    required this.state,
    required this.pendingCount,
    this.lastSyncedAt,
    this.lastAttemptAt,
    this.failureKind,
    this.errorMessage,
  });

  final SyncState state;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final DateTime? lastAttemptAt;
  final SyncFailureKind? failureKind;
  final String? errorMessage;

  bool get hasPendingWrites => pendingCount > 0;
}

/// Fait le pont entre la base locale, qui fait foi pour l'affichage, et
/// Supabase, qui fait foi entre appareils.
///
/// Deux sens indépendants :
///
/// * **push** — les intentions d'écriture accumulées dans la file locale sont
///   rejouées dans l'ordre des dépendances. L'état local est sérialisé au
///   moment de l'envoi, jamais au moment de la mise en file.
/// * **pull** — l'état distant est rapatrié puis réconcilié. Une ligne locale
///   qui porte une intention non poussée est intouchable : l'écriture de
///   l'utilisateur n'est jamais écrasée par une version distante plus ancienne
///   qu'elle n'a pas encore vue.
///
/// Hors ligne, tout échoue silencieusement et reste en file. Rien n'est perdu,
/// rien ne bloque l'interface.
class SyncService {
  SyncService({
    required AppDatabase database,
    required SupabaseClient client,
    Duration retryInterval = const Duration(seconds: 30),
    Duration remoteChangeDebounce = const Duration(milliseconds: 1500),
    Stream<bool>? networkChanges,
  }) : _db = database,
       _client = client,
       _retryInterval = retryInterval,
       _remoteChangeDebounce = remoteChangeDebounce,
       _networkChanges =
           networkChanges ??
           Connectivity().onConnectivityChanged.map(
             (results) =>
                 results.any((result) => result != ConnectivityResult.none),
           );

  static const _tables = ['collections', 'decks', 'flashcards', 'review_logs'];

  final AppDatabase _db;
  final SupabaseClient _client;
  final Duration _retryInterval;
  final Duration _remoteChangeDebounce;
  final Stream<bool> _networkChanges;

  final _statusController = StreamController<SyncStatus>.broadcast();
  var _status = const SyncStatus(state: SyncState.idle, pendingCount: 0);

  RealtimeChannel? _channel;
  Timer? _retryTimer;
  Timer? _debounceTimer;
  StreamSubscription<bool>? _networkSubscription;
  _SyncSession? _session;
  Future<void> _lifecycle = Future.value();
  var _transitionId = 0;
  var _disposed = false;

  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get status => _status;

  /// Prend possession de la base locale pour [userId], puis lance une première
  /// synchronisation. Les données d'un autre compte sont effacées.
  Future<void> startFor(String userId) async {
    if (_disposed) return;
    final currentSession = _session;
    if (currentSession != null &&
        currentSession.userId == userId &&
        _isCurrent(currentSession)) {
      return syncNow();
    }
    final transitionId = ++_transitionId;
    _session = null;
    await _serializeTransition(() async {
      await _stopListeners();
      if (_disposed || transitionId != _transitionId) return;
      await _db.adoptOwner(userId);
      if (_disposed || transitionId != _transitionId) return;
      final session = _session = _SyncSession(userId);
      _emit(const SyncStatus(state: SyncState.idle, pendingCount: 0));
      _listenToRemoteChanges(session);
      _listenToNetworkChanges(session);
      _retryTimer = Timer.periodic(_retryInterval, (_) {
        if (_isActive(session) &&
            (_status.hasPendingWrites ||
                _status.state == SyncState.offline ||
                _status.state == SyncState.error)) {
          unawaited(syncNow());
        }
      });
    });
    if (!_disposed && transitionId == _transitionId) await syncNow();
  }

  /// Coupe la synchronisation et efface les données locales : sur un appareil
  /// partagé, se déconnecter doit vraiment retirer ses cartes de l'appareil.
  Future<void> stopAndClear() {
    if (_disposed) return _lifecycle;
    ++_transitionId;
    _session = null;
    return _serializeTransition(() async {
      await _stopListeners();
      await _db.clearAllUserData();
      _emit(const SyncStatus(state: SyncState.idle, pendingCount: 0));
    });
  }

  Future<void> dispose() {
    if (_disposed) return _lifecycle;
    _disposed = true;
    ++_transitionId;
    _session = null;
    return _serializeTransition(() async {
      await _stopListeners();
      // Drain local transactions before the caller can close the database.
      // Outstanding HTTP requests will be discarded on return.
      await _db.transaction(() async {});
      await _statusController.close();
    });
  }

  Future<void> _serializeTransition(Future<void> Function() action) {
    final next = _lifecycle.then((_) => action());
    _lifecycle = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  bool _isActive(_SyncSession session) =>
      !_disposed && identical(_session, session);

  bool _isCurrent(_SyncSession session) {
    if (!_isActive(session)) return false;
    // Tests and explicitly injected clients may have no GoTrue session. In
    // that case the service's bound session is the authority. When GoTrue has
    // a user, it must agree with the bound account so auth changes invalidate
    // in-flight work.
    final authUserId = _client.auth.currentUser?.id;
    return authUserId == null || authUserId == session.userId;
  }

  void _checkSession(_SyncSession session) {
    if (!_isCurrent(session)) throw const _ExpiredSession();
  }

  Future<T> _localTransaction<T>(
    _SyncSession session,
    Future<T> Function() action,
  ) {
    _checkSession(session);
    return _db.transaction(() async {
      _checkSession(session);
      final result = await action();
      // Roll back if an account transition started during local work.
      _checkSession(session);
      return result;
    });
  }

  /// Pousse la file puis rapatrie l'état distant. Les appels concurrents sont
  /// fusionnés : une demande arrivée pendant une synchronisation en cours en
  /// déclenche exactement une autre derrière.
  Future<void> syncNow() {
    final session = _session;
    // ignore: avoid_print
    if (session == null || !_isCurrent(session)) return Future.value();
    final inFlight = session.inFlight;
    if (inFlight != null) {
      session.syncAgain = true;
      // A caller that arrives during a run owns the follow-up wait as well;
      // otherwise it could observe the old run completing while its queued
      // work is still pending.
      return inFlight.then((_) {
        if (!session.syncAgain || !_isCurrent(session)) {
          return Future<void>.value();
        }
        session.syncAgain = false;
        return syncNow();
      });
    }

    final completion = Completer<void>();
    final run = _runSync(session);
    session.inFlight = completion.future;
    run.then(
      (_) {
        if (identical(session.inFlight, completion.future)) {
          session.inFlight = null;
        }
        completion.complete();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (identical(session.inFlight, completion.future)) {
          session.inFlight = null;
        }
        completion.completeError(error, stackTrace);
      },
    );
    return completion.future;
  }

  Future<void> _runSync(_SyncSession session) async {
    final attemptAt = DateTime.now();
    _emit(
      SyncStatus(
        state: SyncState.syncing,
        pendingCount: _status.pendingCount,
        lastSyncedAt: _status.lastSyncedAt,
        lastAttemptAt: attemptAt,
      ),
    );
    try {
      await _pushPending(session);
      await _pull(session);
      final pendingCount = await _pendingCount(session);
      _checkSession(session);
      _emit(
        SyncStatus(
          state: SyncState.idle,
          pendingCount: pendingCount,
          lastSyncedAt: DateTime.now(),
          lastAttemptAt: attemptAt,
        ),
      );
    } catch (error) {
      if (!_isCurrent(session)) return;
      final failure = classifyFailure(error);
      // La file reste intacte dans tous les cas. Un échec serveur est
      // distingué d'une absence de réseau afin que l'utilisateur puisse agir.
      int pendingCount;
      try {
        pendingCount = await _pendingCount(session);
      } on _ExpiredSession {
        return;
      }
      if (!_isCurrent(session)) return;
      _emit(
        SyncStatus(
          state: failure.kind == SyncFailureKind.network
              ? SyncState.offline
              : SyncState.error,
          pendingCount: pendingCount,
          lastSyncedAt: _status.lastSyncedAt,
          lastAttemptAt: attemptAt,
          failureKind: failure.kind,
          errorMessage: failure.message,
        ),
      );
    }
  }

  static ({SyncFailureKind kind, String message}) classifyFailure(
    Object error,
  ) {
    // PostgREST errors mean that the server was reached, even for 4xx/5xx.
    if (error is PostgrestException) {
      return (
        kind: SyncFailureKind.server,
        message: 'Le serveur a refusé la synchronisation. Réessaie plus tard.',
      );
    }
    final type = error.runtimeType.toString().toLowerCase();
    final text = error.toString().toLowerCase();
    if (type.contains('socket') ||
        type.contains('timeout') ||
        type.contains('clientexception') ||
        text.contains('connection') ||
        text.contains('network') ||
        text.contains('timeout')) {
      return (
        kind: SyncFailureKind.network,
        message: 'Connexion indisponible. Les changements restent en attente.',
      );
    }
    return (
      kind: SyncFailureKind.unknown,
      message: 'La synchronisation a échoué. Réessaie plus tard.',
    );
  }

  // --- Push ---------------------------------------------------------------

  Future<void> _pushPending(_SyncSession session) async {
    final entries = await _localTransaction(session, _db.pendingSyncEntries);
    if (entries.isEmpty) {
      return;
    }

    // Les créations remontent des parents vers les enfants, les suppressions
    // dans l'autre sens : sans cela, une clé étrangère distante casse le push.
    final upserts =
        entries
            .where((entry) => entry.operation == SyncOperation.upsert)
            .toList()
          ..sort((a, b) => _rank(a.entityType).compareTo(_rank(b.entityType)));
    final deletes =
        entries
            .where((entry) => entry.operation == SyncOperation.delete)
            .toList()
          ..sort((a, b) => _rank(b.entityType).compareTo(_rank(a.entityType)));

    for (final entry in upserts) {
      final payload = await _localTransaction(
        session,
        () => _localPayload(entry.entityType, entry.entityId),
      );
      _checkSession(session);
      if (payload == null) {
        // La ligne a disparu localement entre la mise en file et l'envoi.
        await _acknowledge(session, entry);
        continue;
      }
      await _client.from(_tableOf(entry.entityType)).upsert({
        ...payload,
        'user_id': session.userId,
      });
      await _acknowledge(session, entry);
    }

    for (final entry in deletes) {
      _checkSession(session);
      await _client
          .from(_tableOf(entry.entityType))
          .delete()
          .eq('id', entry.entityId)
          .eq('user_id', session.userId);
      await _acknowledge(session, entry);
    }
  }

  Future<void> _acknowledge(_SyncSession session, SyncQueueEntry entry) =>
      _localTransaction(session, () => _db.acknowledgeSyncEntry(entry));

  // --- Pull ---------------------------------------------------------------

  Future<void> _pull(_SyncSession session) async {
    final remoteCollections = await _fetchAll('collections', session);
    final remoteDecks = await _fetchAll('decks', session);
    final remoteFlashcards = await _fetchAll('flashcards', session);

    await _localTransaction(session, () async {
      // Resolve protection after the network awaits, atomically with applying
      // the snapshot. Pending descendants also keep their local ancestors.
      final protectedIds = await _protectedIds();
      await _applyRemoteRows(
        SyncEntityType.collection,
        remoteCollections,
        protectedIds[SyncEntityType.collection]!,
      );
      await _applyRemoteRows(
        SyncEntityType.deck,
        remoteDecks,
        protectedIds[SyncEntityType.deck]!,
      );
      await _applyRemoteRows(
        SyncEntityType.flashcard,
        remoteFlashcards,
        protectedIds[SyncEntityType.flashcard]!,
      );

      // Ce qui a disparu côté distant disparaît côté local, sauf ce qui porte
      // une intention pas encore poussée.
      final keptFlashcards = _keepIds(
        remoteFlashcards,
        protectedIds[SyncEntityType.flashcard]!,
      );
      final keptDecks = _keepIds(
        remoteDecks,
        protectedIds[SyncEntityType.deck]!,
      );
      final keptCollections = _keepIds(
        remoteCollections,
        protectedIds[SyncEntityType.collection]!,
      );
      await (_db.delete(
        _db.flashcards,
      )..where((row) => row.id.isNotIn(keptFlashcards))).go();
      await (_db.delete(
        _db.decks,
      )..where((row) => row.id.isNotIn(keptDecks))).go();
      await (_db.delete(
        _db.collections,
      )..where((row) => row.id.isNotIn(keptCollections))).go();
      await _db.deleteOrphans();
    });

    await _pullReviewLogs(session);
  }

  Future<Map<SyncEntityType, Set<String>>> _protectedIds() async {
    final ids = {for (final type in SyncEntityType.values) type: <String>{}};
    for (final entry in await _db.pendingSyncEntries()) {
      ids[entry.entityType]!.add(entry.entityId);
    }
    final logs = await (_db.select(
      _db.reviewLogs,
    )..where((row) => row.id.isIn(ids[SyncEntityType.reviewLog]!))).get();
    ids[SyncEntityType.flashcard]!.addAll(logs.map((row) => row.flashcardId));
    final cards = await (_db.select(
      _db.flashcards,
    )..where((row) => row.id.isIn(ids[SyncEntityType.flashcard]!))).get();
    ids[SyncEntityType.deck]!.addAll(cards.map((row) => row.deckId));
    ids[SyncEntityType.collection]!.addAll(
      cards.map((row) => row.collectionId),
    );
    final decks = await (_db.select(
      _db.decks,
    )..where((row) => row.id.isIn(ids[SyncEntityType.deck]!))).get();
    ids[SyncEntityType.collection]!.addAll(
      decks.map((row) => row.collectionId),
    );
    return ids;
  }

  /// Les journaux ne sont jamais modifiés ni supprimés directement : on ne
  /// rapatrie que ce qui a été écrit depuis le dernier passage.
  Future<void> _pullReviewLogs(_SyncSession session) async {
    final cursor = await _localTransaction(
      session,
      () => _db.readMetaDateTime(AppDatabase.reviewLogCursorKey),
    );
    final rows = await _fetchAll('review_logs', session, createdAfter: cursor);
    if (rows.isEmpty) {
      return;
    }

    DateTime? newest = cursor;
    await _localTransaction(session, () async {
      for (final row in rows) {
        await _db.applyRemoteRecord(
          RemoteSyncRecord(
            entityType: SyncEntityType.reviewLog,
            entityId: row['id'] as String,
            payload: row,
            updatedAt: DateTime.parse(row['created_at'] as String),
          ),
        );
        final createdAt = DateTime.parse(row['created_at'] as String);
        if (newest == null || createdAt.isAfter(newest!)) {
          newest = createdAt;
        }
      }
      await _db.deleteOrphans();
      if (newest != null) {
        await _db.writeMetaDateTime(AppDatabase.reviewLogCursorKey, newest!);
      }
    });
  }

  Future<void> _applyRemoteRows(
    SyncEntityType entityType,
    List<Map<String, dynamic>> rows,
    Set<String> protectedIds,
  ) async {
    for (final row in rows) {
      final id = row['id'] as String;
      if (protectedIds.contains(id)) {
        continue;
      }
      final remoteUpdatedAt = DateTime.parse(row['updated_at'] as String);
      final localUpdatedAt = await _db.readEntityUpdatedAt(entityType, id);
      if (localUpdatedAt != null && localUpdatedAt.isAfter(remoteUpdatedAt)) {
        continue;
      }
      await _db.applyRemoteRecord(
        RemoteSyncRecord(
          entityType: entityType,
          entityId: id,
          payload: row,
          updatedAt: remoteUpdatedAt,
        ),
      );
    }

    // A pending child wins over a remote parent deletion. Restore any missing
    // local ancestors too, so the next push can satisfy remote foreign keys.
    final missing = protectedIds.difference(
      rows.map((row) => row['id'] as String).toSet(),
    );
    if (missing.isEmpty) return;
    final pendingIds = {
      for (final entry in await _db.pendingSyncEntries())
        if (entry.entityType == entityType) entry.entityId,
    };
    for (final id in missing.difference(pendingIds)) {
      if (await _db.readEntityUpdatedAt(entityType, id) != null) {
        await _db.enqueueSync(
          entityType: entityType,
          entityId: id,
          operation: SyncOperation.upsert,
        );
      }
    }
  }

  static List<String> _keepIds(
    List<Map<String, dynamic>> remoteRows,
    Set<String> protectedIds,
  ) {
    return {
      ...remoteRows.map((row) => row['id'] as String),
      ...protectedIds,
    }.toList();
  }

  Future<List<Map<String, dynamic>>> _fetchAll(
    String table,
    _SyncSession session, {
    DateTime? createdAfter,
  }) async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;

    while (true) {
      _checkSession(session);
      dynamic query = _client
          .from(table)
          .select()
          .eq('user_id', session.userId);
      if (createdAfter != null) {
        query = query.gt('created_at', createdAfter.toUtc().toIso8601String());
      }
      final page = await query
          .order('created_at', ascending: true)
          .range(offset, offset + pageSize - 1);
      _checkSession(session);
      final mapped = (page as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      rows.addAll(mapped);
      if (mapped.length < pageSize) {
        return rows;
      }
      offset += mapped.length;
    }
  }

  // --- Sérialisation locale → distante ------------------------------------

  Future<Map<String, dynamic>?> _localPayload(
    SyncEntityType entityType,
    String entityId,
  ) async {
    switch (entityType) {
      case SyncEntityType.collection:
        final row = await (_db.select(
          _db.collections,
        )..where((table) => table.id.equals(entityId))).getSingleOrNull();
        return row == null ? null : collectionPayload(row);
      case SyncEntityType.deck:
        final row = await (_db.select(
          _db.decks,
        )..where((table) => table.id.equals(entityId))).getSingleOrNull();
        return row == null ? null : deckPayload(row);
      case SyncEntityType.flashcard:
        final row = await (_db.select(
          _db.flashcards,
        )..where((table) => table.id.equals(entityId))).getSingleOrNull();
        return row == null ? null : flashcardPayload(row);
      case SyncEntityType.reviewLog:
        final row = await (_db.select(
          _db.reviewLogs,
        )..where((table) => table.id.equals(entityId))).getSingleOrNull();
        return row == null ? null : reviewLogPayload(row);
    }
  }

  static Map<String, dynamic> collectionPayload(Collection row) {
    return {
      'id': row.id,
      'name': row.name,
      'description': row.description,
      'icon': row.icon,
      'color': row.color,
      'is_disabled': row.isDisabled,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> deckPayload(Deck row) {
    return {
      'id': row.id,
      'collection_id': row.collectionId,
      'name': row.name,
      'icon': row.icon,
      'difficulty': row.difficulty.name,
      'is_disabled': row.isDisabled,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> flashcardPayload(Flashcard row) {
    return {
      'id': row.id,
      'collection_id': row.collectionId,
      'deck_id': row.deckId,
      'question': row.question,
      'correct_answer': row.correctAnswer,
      'answer': row.answer,
      'wrong_answers': row.wrongAnswers,
      'hint': row.hint,
      'explanation': row.explanation,
      'current_test_mode': row.currentTestMode.name,
      'allowed_test_modes': row.allowedTestModes
          .map((mode) => mode.name)
          .toList(),
      'last_test_mode': row.lastTestMode?.name,
      'mode_history': row.modeHistory.map((mode) => mode.name).toList(),
      'cloze_text': row.clozeText,
      'cloze_answers': row.clozeAnswers,
      'cloze_word_bank': row.clozeWordBank,
      'accepted_answers': row.acceptedAnswers,
      'source': row.source,
      'difficulty': row.difficulty?.name,
      'level': row.level,
      'tags': row.tags,
      'due_at': row.dueAt.toUtc().toIso8601String(),
      'last_reviewed_at': row.lastReviewedAt?.toUtc().toIso8601String(),
      'interval_days': row.intervalDays,
      'ease_factor': row.easeFactor,
      'repetitions': row.repetitions,
      'lapses': row.lapses,
      'mastered': row.mastered,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> reviewLogPayload(ReviewLog row) {
    return {
      'id': row.id,
      'flashcard_id': row.flashcardId,
      'collection_id': row.collectionId,
      'deck_id': row.deckId,
      'review_result': row.reviewResult.name,
      'test_mode': row.testMode.name,
      'was_correct': row.wasCorrect,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'scheduled_due_at': row.scheduledDueAt.toUtc().toIso8601String(),
    };
  }

  // --- Temps réel ---------------------------------------------------------

  void _listenToRemoteChanges(_SyncSession session) {
    if (_channel != null) {
      return;
    }
    final channel = _client.channel('memflow-sync-${session.userId}');
    for (final table in _tables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: session.userId,
        ),
        callback: (_) => _scheduleRemotePull(session),
      );
    }
    _channel = channel..subscribe();
  }

  /// Un changement distant peut être le nôtre qui revient : on laisse retomber
  /// la rafale avant de rapatrier, pour ne pas relire la base à chaque ligne
  /// d'un import.
  void _scheduleRemotePull(_SyncSession session) {
    if (!_isActive(session)) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_remoteChangeDebounce, () {
      if (_isActive(session)) {
        unawaited(syncNow());
      }
    });
  }

  void _listenToNetworkChanges(_SyncSession session) {
    if (_networkSubscription != null) {
      return;
    }
    _networkSubscription = _networkChanges.listen((isConnected) {
      if (isConnected && _isActive(session)) {
        // The periodic timer remains the fallback for missed connectivity
        // notifications.
        unawaited(syncNow());
      }
    });
  }

  Future<void> _stopListeners() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final networkSubscription = _networkSubscription;
    _networkSubscription = null;
    final channel = _channel;
    _channel = null;
    await networkSubscription?.cancel();
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  // --- Utilitaires --------------------------------------------------------

  Future<int> _pendingCount(_SyncSession session) => _localTransaction(
    session,
    () async => (await _db.pendingSyncEntries()).length,
  );

  void _emit(SyncStatus status) {
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  static int _rank(SyncEntityType type) => switch (type) {
    SyncEntityType.collection => 0,
    SyncEntityType.deck => 1,
    SyncEntityType.flashcard => 2,
    SyncEntityType.reviewLog => 3,
  };

  static String _tableOf(SyncEntityType type) => switch (type) {
    SyncEntityType.collection => 'collections',
    SyncEntityType.deck => 'decks',
    SyncEntityType.flashcard => 'flashcards',
    SyncEntityType.reviewLog => 'review_logs',
  };
}

class _SyncSession {
  _SyncSession(this.userId);

  final String userId;
  Future<void>? inFlight;
  bool syncAgain = false;
}

class _ExpiredSession implements Exception {
  const _ExpiredSession();
}
