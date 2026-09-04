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
  Future<void>? _inFlight;
  var _syncAgain = false;
  var _disposed = false;

  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get status => _status;

  String? get _userId => _client.auth.currentUser?.id;

  /// Prend possession de la base locale pour [userId], puis lance une première
  /// synchronisation. Les données d'un autre compte sont effacées.
  Future<void> startFor(String userId) async {
    await _db.adoptOwner(userId);
    _listenToRemoteChanges();
    _listenToNetworkChanges();
    _retryTimer ??= Timer.periodic(_retryInterval, (_) {
      if (_status.hasPendingWrites ||
          _status.state == SyncState.offline ||
          _status.state == SyncState.error) {
        unawaited(syncNow());
      }
    });
    await syncNow();
  }

  /// Coupe la synchronisation et efface les données locales : sur un appareil
  /// partagé, se déconnecter doit vraiment retirer ses cartes de l'appareil.
  Future<void> stopAndClear() async {
    await _teardownChannel();
    await _networkSubscription?.cancel();
    _networkSubscription = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _db.clearAllUserData();
    _emit(const SyncStatus(state: SyncState.idle, pendingCount: 0));
  }

  Future<void> dispose() async {
    _disposed = true;
    await _teardownChannel();
    await _networkSubscription?.cancel();
    _retryTimer?.cancel();
    _debounceTimer?.cancel();
    await _statusController.close();
  }

  /// Pousse la file puis rapatrie l'état distant. Les appels concurrents sont
  /// fusionnés : une demande arrivée pendant une synchronisation en cours en
  /// déclenche exactement une autre derrière.
  Future<void> syncNow() {
    final inFlight = _inFlight;
    if (inFlight != null) {
      _syncAgain = true;
      return inFlight;
    }

    final run = _runSync().whenComplete(() {
      _inFlight = null;
      if (_syncAgain && !_disposed) {
        _syncAgain = false;
        unawaited(syncNow());
      }
    });
    _inFlight = run;
    return run;
  }

  Future<void> _runSync() async {
    if (_userId == null) {
      return;
    }

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
      await _pushPending();
      await _pull();
      _emit(
        SyncStatus(
          state: SyncState.idle,
          pendingCount: await _pendingCount(),
          lastSyncedAt: DateTime.now(),
          lastAttemptAt: attemptAt,
        ),
      );
    } catch (error) {
      final failure = classifyFailure(error);
      // La file reste intacte dans tous les cas. Un échec serveur est
      // distingué d'une absence de réseau afin que l'utilisateur puisse agir.
      _emit(
        SyncStatus(
          state: failure.kind == SyncFailureKind.network
              ? SyncState.offline
              : SyncState.error,
          pendingCount: await _pendingCount(),
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

  Future<void> _pushPending() async {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    final entries = await _db.pendingSyncEntries();
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
      final payload = await _localPayload(entry.entityType, entry.entityId);
      if (payload == null) {
        // La ligne a disparu localement entre la mise en file et l'envoi.
        await _db.deleteSyncQueueEntry(entry.id);
        continue;
      }
      await _client.from(_tableOf(entry.entityType)).upsert({
        ...payload,
        'user_id': userId,
      });
      await _db.deleteSyncQueueEntry(entry.id);
    }

    for (final entry in deletes) {
      await _client
          .from(_tableOf(entry.entityType))
          .delete()
          .eq('id', entry.entityId)
          .eq('user_id', userId);
      await _db.deleteSyncQueueEntry(entry.id);
    }
  }

  // --- Pull ---------------------------------------------------------------

  Future<void> _pull() async {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    final protectedIds = {
      for (final entry in await _db.pendingSyncEntries()) entry.entityId,
    };

    final remoteCollections = await _fetchAll('collections', userId);
    final remoteDecks = await _fetchAll('decks', userId);
    final remoteFlashcards = await _fetchAll('flashcards', userId);

    await _db.transaction(() async {
      await _applyRemoteRows(
        SyncEntityType.collection,
        remoteCollections,
        protectedIds,
      );
      await _applyRemoteRows(SyncEntityType.deck, remoteDecks, protectedIds);
      await _applyRemoteRows(
        SyncEntityType.flashcard,
        remoteFlashcards,
        protectedIds,
      );

      // Ce qui a disparu côté distant disparaît côté local, sauf ce qui porte
      // une intention pas encore poussée.
      final keptFlashcards = _keepIds(remoteFlashcards, protectedIds);
      final keptDecks = _keepIds(remoteDecks, protectedIds);
      final keptCollections = _keepIds(remoteCollections, protectedIds);
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

    await _pullReviewLogs(userId);
  }

  /// Les journaux ne sont jamais modifiés ni supprimés directement : on ne
  /// rapatrie que ce qui a été écrit depuis le dernier passage.
  Future<void> _pullReviewLogs(String userId) async {
    final cursor = await _db.readMetaDateTime(AppDatabase.reviewLogCursorKey);
    final rows = await _fetchAll('review_logs', userId, createdAfter: cursor);
    if (rows.isEmpty) {
      return;
    }

    DateTime? newest = cursor;
    await _db.transaction(() async {
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
    });

    if (newest != null) {
      await _db.writeMetaDateTime(AppDatabase.reviewLogCursorKey, newest!);
    }
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
    String userId, {
    DateTime? createdAfter,
  }) async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;

    while (true) {
      dynamic query = _client.from(table).select().eq('user_id', userId);
      if (createdAfter != null) {
        query = query.gt('created_at', createdAfter.toUtc().toIso8601String());
      }
      final page = await query
          .order('created_at', ascending: true)
          .range(offset, offset + pageSize - 1);
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

  void _listenToRemoteChanges() {
    if (_channel != null) {
      return;
    }
    final channel = _client.channel('memflow-sync');
    for (final table in _tables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _scheduleRemotePull(),
      );
    }
    _channel = channel..subscribe();
  }

  /// Un changement distant peut être le nôtre qui revient : on laisse retomber
  /// la rafale avant de rapatrier, pour ne pas relire la base à chaque ligne
  /// d'un import.
  void _scheduleRemotePull() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_remoteChangeDebounce, () {
      if (!_disposed) {
        unawaited(syncNow());
      }
    });
  }

  void _listenToNetworkChanges() {
    if (_networkSubscription != null) {
      return;
    }
    _networkSubscription = _networkChanges.listen((isConnected) {
      if (isConnected && !_disposed) {
        // The periodic timer remains the fallback for missed connectivity
        // notifications.
        unawaited(syncNow());
      }
    });
  }

  Future<void> _teardownChannel() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  // --- Utilitaires --------------------------------------------------------

  Future<int> _pendingCount() async => (await _db.pendingSyncEntries()).length;

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

extension on SyncStatus {
  SyncStatus copyWith({
    SyncState? state,
    int? pendingCount,
    DateTime? lastSyncedAt,
  }) {
    return SyncStatus(
      state: state ?? this.state,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }
}
