import 'dart:async';
import 'dart:math' as math;

import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:uuid/uuid.dart';

import '../../domain/models/models.dart';
import '../../domain/services/card_mode_service.dart';
import '../../domain/services/spaced_repetition_service.dart';
import '../local/database.dart';
import '../sync/sync_service.dart';
import 'stream_combine.dart';

/// Accès unique aux données de l'application.
///
/// Toutes les lectures viennent de la base locale : l'interface n'attend
/// jamais le réseau et fonctionne à l'identique hors ligne. Toutes les
/// écritures sont appliquées localement puis déposées dans la file de
/// synchronisation, que [SyncService] pousse dès qu'une connexion est
/// disponible.
class AppRepository {
  AppRepository({
    required AppDatabase database,
    required SyncService syncService,
    required SpacedRepetitionService spacedRepetitionService,
    required CardModeService cardModeService,
  }) : _db = database,
       _sync = syncService,
       _spacedRepetitionService = spacedRepetitionService,
       _cardModeService = cardModeService;

  final AppDatabase _db;
  final SyncService _sync;
  final SpacedRepetitionService _spacedRepetitionService;
  final CardModeService _cardModeService;
  final Uuid _uuid = const Uuid();

  // ---------------------------------------------------------------------
  // Listes et tableaux de bord
  // ---------------------------------------------------------------------

  Stream<List<CollectionListItem>> watchCollections({String search = ''}) {
    final lowered = search.trim().toLowerCase();
    return combineLatest5(
      _watchCollections(),
      _watchDecks(),
      _watchFlashcards(),
      _watchErrorCountsByCollection(),
      _clockStream(),
      (collections, decks, flashcards, errorCounts, now) {
        final activeCards = _excludeDisabledDeckCards(flashcards, decks);
        final items =
            collections
                .map(
                  (collection) => _buildCollectionListItem(
                    collection,
                    activeCards
                        .where((card) => card.collectionId == collection.id)
                        .toList(),
                    errorCounts[collection.id] ?? 0,
                    now,
                  ),
                )
                .where(
                  (item) =>
                      lowered.isEmpty ||
                      item.name.toLowerCase().contains(lowered),
                )
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
        return items;
      },
    );
  }

  Stream<CollectionListItem?> watchCollection(String id) {
    return watchCollections().map(
      (items) => _firstWhereOrNull(items, (item) => item.id == id),
    );
  }

  Stream<List<DeckListItem>> watchDecksForCollection(String collectionId) {
    return combineLatest3(
      _watchDecks(collectionId: collectionId),
      _watchFlashcards(collectionId: collectionId),
      _clockStream(),
      (decks, flashcards, now) {
        final items =
            decks
                .map(
                  (deck) => _buildDeckListItem(
                    deck,
                    flashcards.where((card) => card.deckId == deck.id).toList(),
                    now,
                  ),
                )
                .toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return items;
      },
    );
  }

  Stream<HomeStats> watchHomeStats() {
    return combineLatest5(
      _watchCollections(),
      _watchDecks(),
      _watchFlashcards(),
      _watchReviewTotals(),
      _clockStream(),
      (collections, decks, flashcards, totals, now) {
        final available = _excludeUnavailableCards(
          flashcards,
          collections: collections,
          decks: decks,
        );
        return HomeStats(
          streakDays: _calculateStreak(totals.dayCounts.keys, now: now),
          successRate: totals.successRate,
          dueCards: available
              .where((card) => !_isDueInFuture(card.dueAt, now))
              .length,
          totalCardsSeen: totals.total,
        );
      },
    );
  }

  Stream<StatisticsOverview> watchStatisticsOverview() {
    return combineLatest5(
      _watchCollections(),
      _watchFlashcards(),
      _watchReviewTotals(),
      _watchReviewLogs(),
      _clockStream(),
      (collections, flashcards, totals, logs, now) =>
          _buildStatisticsOverview(collections, flashcards, totals, logs, now),
    );
  }

  // ---------------------------------------------------------------------
  // Session d'étude
  // ---------------------------------------------------------------------

  Future<StudySessionState> startStudySession({
    String? collectionId,
    String? deckId,
    TestMode? forcedMode,
    required int sessionCardLimit,
  }) async {
    final now = DateTime.now();
    final cards = await _loadSessionCards(
      collectionId: collectionId,
      deckId: deckId,
      now: now,
      sessionCardLimit: sessionCardLimit,
    );

    if (cards.isEmpty) {
      throw StateError('Aucune carte disponible pour cette session.');
    }

    var title = 'Révision';
    if (deckId != null) {
      final deck = await _fetchDeck(deckId);
      if (deck == null) {
        throw StateError('Deck introuvable.');
      }
      title = deck.name;
    } else if (collectionId != null) {
      final collection = await _fetchCollection(collectionId);
      if (collection == null) {
        throw StateError('Collection introuvable.');
      }
      title = collection.name;
    }

    return StudySessionState(
      deckTitle: title,
      collectionId: collectionId,
      deckId: deckId,
      cards: cards
          .map((card) => _mapStudyCard(card, forcedMode: forcedMode))
          .toList(),
      currentIndex: 0,
      revealed: false,
      selectedOptionIndex: null,
      hasValidatedAnswer: false,
      freeTextAnswer: '',
      reviewCounts: {
        ReviewResult.again: 0,
        ReviewResult.hard: 0,
        ReviewResult.good: 0,
        ReviewResult.easy: 0,
      },
      currentAnswerWasCorrect: null,
      isCompleted: false,
    );
  }

  /// Enregistre une révision. [playedMode] est le mode réellement présenté à
  /// l'utilisateur : c'est lui qui est journalisé et qui fait avancer la carte,
  /// pas le mode stocké, qui peut différer quand un mode est imposé pour toute
  /// la session.
  Future<void> submitReview({
    required String cardId,
    required ReviewResult reviewResult,
    required bool wasCorrect,
    required TestMode playedMode,
  }) async {
    final now = DateTime.now();
    final card = await _fetchFlashcard(cardId);
    if (card == null) {
      throw StateError('Carte introuvable.');
    }

    final scheduleUpdate = _spacedRepetitionService.applyReview(
      card,
      reviewResult,
      now: now,
    );
    final nextMode = _cardModeService.nextMode(
      card,
      reviewResult,
      playedMode: playedMode,
    );

    final updatedCard = card.copyWith(
      currentTestMode: nextMode,
      lastTestMode: playedMode,
      modeHistory: _cardModeService.updatedModeHistory(
        card,
        nextMode,
        playedMode: playedMode,
      ),
      dueAt: scheduleUpdate.dueAt,
      lastReviewedAt: scheduleUpdate.lastReviewedAt,
      intervalDays: scheduleUpdate.intervalDays,
      easeFactor: scheduleUpdate.easeFactor,
      repetitions: scheduleUpdate.repetitions,
      lapses: scheduleUpdate.lapses,
      mastered: scheduleUpdate.mastered,
      updatedAt: now,
    );

    final log = ReviewLogRecord(
      id: _uuid.v4(),
      flashcardId: card.id,
      collectionId: card.collectionId,
      deckId: card.deckId,
      reviewResult: reviewResult,
      testMode: playedMode,
      wasCorrect: wasCorrect,
      createdAt: now,
      scheduledDueAt: card.dueAt,
    );

    await _db.transaction(() async {
      await _db
          .into(_db.flashcards)
          .insertOnConflictUpdate(_flashcardCompanion(updatedCard));
      await _db
          .into(_db.reviewLogs)
          .insertOnConflictUpdate(_reviewLogCompanion(log));
      await _db.enqueueSync(
        entityType: SyncEntityType.flashcard,
        entityId: card.id,
        operation: SyncOperation.upsert,
      );
      await _db.enqueueSync(
        entityType: SyncEntityType.reviewLog,
        entityId: log.id,
        operation: SyncOperation.upsert,
      );
    });
    _requestSync();
  }

  // ---------------------------------------------------------------------
  // Import et export
  // ---------------------------------------------------------------------

  Future<void> importCards(CsvImportPreview preview) async {
    if (preview.cards.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final collections = await _fetchCollections();
    final decks = await _fetchDecks();
    final collectionsByName = {
      for (final collection in collections)
        collection.name.toLowerCase(): collection,
    };
    final decksByKey = {
      for (final deck in decks)
        '${deck.collectionId}:${deck.name.toLowerCase()}': deck,
    };

    await _db.transaction(() async {
      for (final draft in preview.cards) {
        final collectionKey = draft.collection.toLowerCase();
        var collection = collectionsByName[collectionKey];
        if (collection == null) {
          collection = CollectionRecord(
            id: _uuid.v4(),
            name: draft.collection,
            description: 'Import CSV',
            icon: '📚',
            color: 0xFFE8792F,
            createdAt: now,
            updatedAt: now,
          );
          await _db
              .into(_db.collections)
              .insertOnConflictUpdate(_collectionCompanion(collection));
          await _db.enqueueSync(
            entityType: SyncEntityType.collection,
            entityId: collection.id,
            operation: SyncOperation.upsert,
          );
          collectionsByName[collectionKey] = collection;
        }

        final deckKey = '${collection.id}:${draft.deck.toLowerCase()}';
        var deck = decksByKey[deckKey];
        if (deck == null) {
          deck = DeckRecord(
            id: _uuid.v4(),
            collectionId: collection.id,
            name: draft.deck,
            icon: '🗂️',
            difficulty: draft.difficulty,
            createdAt: now,
            updatedAt: now,
          );
          await _db
              .into(_db.decks)
              .insertOnConflictUpdate(_deckCompanion(deck));
          await _db.enqueueSync(
            entityType: SyncEntityType.deck,
            entityId: deck.id,
            operation: SyncOperation.upsert,
          );
          decksByKey[deckKey] = deck;
        }

        final card = FlashcardRecord(
          id: _uuid.v4(),
          collectionId: collection.id,
          deckId: deck.id,
          question: draft.question,
          correctAnswer: draft.correctAnswer,
          answer: draft.correctAnswer,
          wrongAnswers: draft.wrongAnswers,
          hint: draft.hint,
          explanation: draft.explanation,
          currentTestMode: TestMode.multipleChoice,
          allowedTestModes: draft.allowedTestModes,
          lastTestMode: null,
          modeHistory: const [TestMode.multipleChoice],
          clozeText: draft.clozeText,
          clozeAnswers: draft.clozeAnswers,
          clozeWordBank: draft.clozeWordBank,
          acceptedAnswers: draft.acceptedAnswers,
          source: draft.source,
          difficulty: draft.difficulty,
          level: draft.level,
          tags: draft.tags,
          dueAt: now,
          lastReviewedAt: null,
          intervalDays: 0,
          easeFactor: 2.5,
          repetitions: 0,
          lapses: 0,
          mastered: false,
          createdAt: now,
          updatedAt: now,
        );
        await _db
            .into(_db.flashcards)
            .insertOnConflictUpdate(_flashcardCompanion(card));
        await _db.enqueueSync(
          entityType: SyncEntityType.flashcard,
          entityId: card.id,
          operation: SyncOperation.upsert,
        );
      }
    });
    _requestSync();
  }

  Future<String> exportAllCardsCsv() async {
    final collections = await _fetchCollections();
    final decks = await _fetchDecks();
    final cards = await _fetchFlashcards();

    final collectionMap = {
      for (final collection in collections) collection.id: collection.name,
    };
    final deckMap = {for (final deck in decks) deck.id: deck.name};
    final rows = <List<String>>[csvHeader];

    for (final card in cards) {
      rows.add([
        collectionMap[card.collectionId] ?? '',
        deckMap[card.deckId] ?? '',
        card.question,
        card.correctAnswer,
        card.wrongAnswers.elementAtOrNull(0) ?? '',
        card.wrongAnswers.elementAtOrNull(1) ?? '',
        card.wrongAnswers.elementAtOrNull(2) ?? '',
        card.hint ?? '',
        card.explanation ?? '',
        card.level.toString(),
        card.difficulty?.name ?? '',
        card.tags.join('|'),
        card.source ?? '',
        card.clozeText ?? '',
        card.acceptedAnswers.join('|'),
        card.clozeAnswers.join('|'),
        card.clozeWordBank.join('|'),
      ]);
    }

    return Csv(fieldDelimiter: ';').encode(rows);
  }

  static const csvHeader = [
    'collection',
    'deck',
    'question',
    'correct_answer',
    'wrong_answer_1',
    'wrong_answer_2',
    'wrong_answer_3',
    'hint',
    'explanation',
    'level',
    'difficulty',
    'tags',
    'source',
    'cloze_text',
    'accepted_answers',
    'cloze_answers',
    'cloze_word_bank',
  ];

  // ---------------------------------------------------------------------
  // Listes paginées
  // ---------------------------------------------------------------------

  Stream<List<FlashcardSummary>> watchFlashcardsForDeck(String deckId) {
    return _watchFlashcards(deckId: deckId).map((cards) {
      final sorted = [...cards]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return sorted.map(_toSummary).toList();
    });
  }

  Future<PaginatedSlice<FlashcardSummary>> fetchFlashcardsForDeckPage({
    required String deckId,
    required int offset,
    required int limit,
  }) async {
    final totalCount = await _countFlashcards(
      (table) => table.deckId.equals(deckId),
    );
    if (totalCount == 0) {
      return const PaginatedSlice(items: [], totalCount: 0);
    }

    final rows =
        await (_db.select(_db.flashcards)
              ..where((table) => table.deckId.equals(deckId))
              ..orderBy([
                (table) => OrderingTerm(expression: table.createdAt),
                (table) => OrderingTerm(expression: table.id),
              ])
              ..limit(limit, offset: offset))
            .get();

    return PaginatedSlice(
      items: rows.map(_toFlashcardRecord).map(_toSummary).toList(),
      totalCount: totalCount,
    );
  }

  /// Signale qu'une liste paginée doit se rafraîchir. Le signal n'est pas
  /// filtré : la pagination refait de toute façon sa propre requête, elle,
  /// bornée à sa page.
  Stream<int> watchDeckCardsRevision() => _tableTicks({_db.flashcards});

  Stream<List<FlashcardDueItem>> watchDueCardsForCollection(
    String collectionId,
  ) {
    return combineLatest4(
      _watchCollections(),
      _watchFlashcards(collectionId: collectionId),
      _watchDecks(collectionId: collectionId),
      _clockStream(),
      (collections, cards, decks, now) {
        final deckNames = {for (final deck in decks) deck.id: deck.name};
        final sortedCards =
            [
              ..._excludeUnavailableCards(
                cards,
                collections: collections,
                decks: decks,
              ),
            ]..sort((a, b) {
              final byDueAt = a.dueAt.compareTo(b.dueAt);
              if (byDueAt != 0) {
                return byDueAt;
              }

              final byDeckName = (deckNames[a.deckId] ?? '')
                  .toLowerCase()
                  .compareTo((deckNames[b.deckId] ?? '').toLowerCase());
              if (byDeckName != 0) {
                return byDeckName;
              }

              return a.question.toLowerCase().compareTo(
                b.question.toLowerCase(),
              );
            });

        return sortedCards
            .map(
              (card) => FlashcardDueItem(
                id: card.id,
                deckId: card.deckId,
                deckName: deckNames[card.deckId] ?? 'Deck',
                question: card.question,
                dueAt: card.dueAt,
                isDueNow: !_isDueInFuture(card.dueAt, now),
              ),
            )
            .toList();
      },
    );
  }

  Future<PaginatedSlice<FlashcardDueItem>> fetchDueCardsForCollectionPage({
    required String collectionId,
    required int offset,
    required int limit,
  }) async {
    final collection = await _fetchCollection(collectionId);
    if (collection == null || collection.isDisabled) {
      return const PaginatedSlice(items: [], totalCount: 0);
    }

    final activeDecks = (await _fetchDecks(
      collectionId: collectionId,
    )).where((deck) => !deck.isDisabled).toList();
    if (activeDecks.isEmpty) {
      return const PaginatedSlice(items: [], totalCount: 0);
    }

    final deckNames = {for (final deck in activeDecks) deck.id: deck.name};
    final activeDeckIds = activeDecks.map((deck) => deck.id).toList();

    final totalCount = await _countFlashcards(
      (table) =>
          table.collectionId.equals(collectionId) &
          table.deckId.isIn(activeDeckIds),
    );
    if (totalCount == 0) {
      return const PaginatedSlice(items: [], totalCount: 0);
    }

    final rows =
        await (_db.select(_db.flashcards)
              ..where(
                (table) =>
                    table.collectionId.equals(collectionId) &
                    table.deckId.isIn(activeDeckIds),
              )
              ..orderBy([
                (table) => OrderingTerm(expression: table.dueAt),
                (table) => OrderingTerm(expression: table.id),
              ])
              ..limit(limit, offset: offset))
            .get();

    final now = DateTime.now();
    return PaginatedSlice(
      items: rows.map(_toFlashcardRecord).map((card) {
        return FlashcardDueItem(
          id: card.id,
          deckId: card.deckId,
          deckName: deckNames[card.deckId] ?? 'Deck',
          question: card.question,
          dueAt: card.dueAt,
          isDueNow: !_isDueInFuture(card.dueAt, now),
        );
      }).toList(),
      totalCount: totalCount,
    );
  }

  Stream<int> watchDueCardsForCollectionRevision() =>
      _tableTicks({_db.flashcards, _db.decks, _db.collections});

  // ---------------------------------------------------------------------
  // Écritures
  // ---------------------------------------------------------------------

  Future<void> deleteFlashcard(String cardId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.reviewLogs,
      )..where((table) => table.flashcardId.equals(cardId))).go();
      await (_db.delete(
        _db.flashcards,
      )..where((table) => table.id.equals(cardId))).go();
      await _db.enqueueSync(
        entityType: SyncEntityType.flashcard,
        entityId: cardId,
        operation: SyncOperation.delete,
      );
    });
    _requestSync();
  }

  Future<void> updateFlashcardDueAt({
    required String cardId,
    required DateTime dueAt,
  }) async {
    final card = await _fetchFlashcard(cardId);
    if (card == null) {
      return;
    }
    await _writeFlashcard(
      card.copyWith(dueAt: dueAt, updatedAt: DateTime.now()),
    );
  }

  Future<void> deleteDeck(String deckId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.reviewLogs,
      )..where((table) => table.deckId.equals(deckId))).go();
      await (_db.delete(
        _db.flashcards,
      )..where((table) => table.deckId.equals(deckId))).go();
      await (_db.delete(
        _db.decks,
      )..where((table) => table.id.equals(deckId))).go();
      await _db.enqueueSync(
        entityType: SyncEntityType.deck,
        entityId: deckId,
        operation: SyncOperation.delete,
      );
    });
    _requestSync();
  }

  Future<void> deleteCollection(String collectionId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.reviewLogs,
      )..where((table) => table.collectionId.equals(collectionId))).go();
      await (_db.delete(
        _db.flashcards,
      )..where((table) => table.collectionId.equals(collectionId))).go();
      await (_db.delete(
        _db.decks,
      )..where((table) => table.collectionId.equals(collectionId))).go();
      await (_db.delete(
        _db.collections,
      )..where((table) => table.id.equals(collectionId))).go();
      await _db.enqueueSync(
        entityType: SyncEntityType.collection,
        entityId: collectionId,
        operation: SyncOperation.delete,
      );
    });
    _requestSync();
  }

  Future<void> setDeckDisabled(String deckId, bool isDisabled) async {
    final deck = await _fetchDeck(deckId);
    if (deck == null) {
      return;
    }
    await _writeDeck(
      DeckRecord(
        id: deck.id,
        collectionId: deck.collectionId,
        name: deck.name,
        icon: deck.icon,
        difficulty: deck.difficulty,
        createdAt: deck.createdAt,
        updatedAt: DateTime.now(),
        isDisabled: isDisabled,
      ),
    );
  }

  Future<void> setCollectionDisabled(
    String collectionId,
    bool isDisabled,
  ) async {
    final collection = await _fetchCollection(collectionId);
    if (collection == null) {
      return;
    }
    await _writeCollection(_copyCollection(collection, isDisabled: isDisabled));
  }

  Future<void> setCollectionIcon(String collectionId, String icon) async {
    final collection = await _fetchCollection(collectionId);
    if (collection == null) {
      return;
    }
    await _writeCollection(_copyCollection(collection, icon: icon));
  }

  Future<void> _writeCollection(CollectionRecord collection) async {
    await _db.transaction(() async {
      await _db
          .into(_db.collections)
          .insertOnConflictUpdate(_collectionCompanion(collection));
      await _db.enqueueSync(
        entityType: SyncEntityType.collection,
        entityId: collection.id,
        operation: SyncOperation.upsert,
      );
    });
    _requestSync();
  }

  Future<void> _writeDeck(DeckRecord deck) async {
    await _db.transaction(() async {
      await _db.into(_db.decks).insertOnConflictUpdate(_deckCompanion(deck));
      await _db.enqueueSync(
        entityType: SyncEntityType.deck,
        entityId: deck.id,
        operation: SyncOperation.upsert,
      );
    });
    _requestSync();
  }

  Future<void> _writeFlashcard(FlashcardRecord card) async {
    await _db.transaction(() async {
      await _db
          .into(_db.flashcards)
          .insertOnConflictUpdate(_flashcardCompanion(card));
      await _db.enqueueSync(
        entityType: SyncEntityType.flashcard,
        entityId: card.id,
        operation: SyncOperation.upsert,
      );
    });
    _requestSync();
  }

  /// La synchronisation ne bloque jamais une écriture : l'utilisateur voit sa
  /// modification tout de suite, le réseau suit quand il peut.
  void _requestSync() => unawaited(_sync.syncNow());

  // ---------------------------------------------------------------------
  // Lectures locales
  // ---------------------------------------------------------------------

  Stream<List<CollectionRecord>> _watchCollections() {
    return _db
        .select(_db.collections)
        .watch()
        .map((rows) => rows.map(_toCollectionRecord).toList());
  }

  Stream<List<DeckRecord>> _watchDecks({String? collectionId}) {
    final query = _db.select(_db.decks);
    if (collectionId != null) {
      query.where((table) => table.collectionId.equals(collectionId));
    }
    return query.watch().map((rows) => rows.map(_toDeckRecord).toList());
  }

  Stream<List<FlashcardRecord>> _watchFlashcards({
    String? collectionId,
    String? deckId,
  }) {
    final query = _db.select(_db.flashcards);
    if (collectionId != null) {
      query.where((table) => table.collectionId.equals(collectionId));
    }
    if (deckId != null) {
      query.where((table) => table.deckId.equals(deckId));
    }
    return query.watch().map((rows) => rows.map(_toFlashcardRecord).toList());
  }

  /// Les journaux de révision ne cessent de grossir : on n'en matérialise
  /// jamais les lignes, seulement les agrégats dont les écrans ont besoin.
  Stream<_ReviewTotals> _watchReviewTotals() {
    return _db
        .customSelect(
          'SELECT COUNT(*) AS total, '
          'SUM(CASE WHEN was_correct THEN 1 ELSE 0 END) AS correct, '
          'created_at AS day FROM review_logs GROUP BY created_at',
          readsFrom: {_db.reviewLogs},
        )
        .watch()
        .map(_toReviewTotals);
  }

  Stream<List<ReviewLogRecord>> _watchReviewLogs() {
    return _db
        .select(_db.reviewLogs)
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => ReviewLogRecord(
                  id: row.id,
                  flashcardId: row.flashcardId,
                  collectionId: row.collectionId,
                  deckId: row.deckId,
                  reviewResult: row.reviewResult,
                  testMode: row.testMode,
                  wasCorrect: row.wasCorrect,
                  createdAt: row.createdAt,
                  scheduledDueAt: row.scheduledDueAt,
                ),
              )
              .toList(),
        );
  }

  Stream<Map<String, int>> _watchErrorCountsByCollection() {
    return _db
        .customSelect(
          'SELECT collection_id, COUNT(*) AS errors FROM review_logs '
          'WHERE was_correct = 0 GROUP BY collection_id',
          readsFrom: {_db.reviewLogs},
        )
        .watch()
        .map(
          (rows) => {
            for (final row in rows)
              row.read<String>('collection_id'): row.read<int>('errors'),
          },
        );
  }

  Stream<int> _tableTicks(Set<TableInfo<Table, dynamic>> tables) {
    var tick = 0;
    return _db
        .tableUpdates(TableUpdateQuery.onAllTables(tables))
        .map((_) => ++tick);
  }

  Future<CollectionRecord?> _fetchCollection(String id) async {
    final row = await (_db.select(
      _db.collections,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toCollectionRecord(row);
  }

  Future<DeckRecord?> _fetchDeck(String id) async {
    final row = await (_db.select(
      _db.decks,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDeckRecord(row);
  }

  Future<FlashcardRecord?> _fetchFlashcard(String id) async {
    final row = await (_db.select(
      _db.flashcards,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toFlashcardRecord(row);
  }

  Future<List<CollectionRecord>> _fetchCollections() async {
    final rows = await _db.select(_db.collections).get();
    return rows.map(_toCollectionRecord).toList();
  }

  Future<List<DeckRecord>> _fetchDecks({String? collectionId}) async {
    final query = _db.select(_db.decks);
    if (collectionId != null) {
      query.where((table) => table.collectionId.equals(collectionId));
    }
    return (await query.get()).map(_toDeckRecord).toList();
  }

  Future<List<FlashcardRecord>> _fetchFlashcards({
    String? collectionId,
    String? deckId,
    DateTime? dueBeforeOrAt,
  }) async {
    final query = _db.select(_db.flashcards);
    if (collectionId != null) {
      query.where((table) => table.collectionId.equals(collectionId));
    }
    if (deckId != null) {
      query.where((table) => table.deckId.equals(deckId));
    }
    if (dueBeforeOrAt != null) {
      // La colonne est stockée en millisecondes : la comparaison porte sur la
      // valeur SQL, pas sur le DateTime converti.
      query.where(
        (table) => table.dueAt.isSmallerOrEqualValue(
          dueBeforeOrAt.millisecondsSinceEpoch,
        ),
      );
    }
    return (await query.get()).map(_toFlashcardRecord).toList();
  }

  Future<int> _countFlashcards(
    Expression<bool> Function($FlashcardsTable table) filter,
  ) async {
    final count = _db.flashcards.id.count();
    final query = _db.selectOnly(_db.flashcards)
      ..addColumns([count])
      ..where(filter(_db.flashcards));
    return (await query.getSingle()).read(count) ?? 0;
  }

  // ---------------------------------------------------------------------
  // Composition de session
  // ---------------------------------------------------------------------

  Future<List<FlashcardRecord>> _loadSessionCards({
    required String? collectionId,
    required String? deckId,
    required DateTime now,
    required int sessionCardLimit,
  }) async {
    final disabledDeckIds = {
      for (final deck in await _fetchDecks())
        if (deck.isDisabled) deck.id,
    };
    final disabledCollectionIds = {
      for (final collection in await _fetchCollections())
        if (collection.isDisabled) collection.id,
    };
    bool isActive(FlashcardRecord card) =>
        !disabledDeckIds.contains(card.deckId) &&
        !disabledCollectionIds.contains(card.collectionId);

    final retryCards = (await _fetchFailedFlashcards(
      collectionId: collectionId,
      deckId: deckId,
    )).where(isActive).toList();

    final dueActiveCards = (await _fetchFlashcards(
      collectionId: collectionId,
      deckId: deckId,
      dueBeforeOrAt: now,
    )).where(isActive).toList();

    final fillerCards = dueActiveCards.isNotEmpty
        ? dueActiveCards
        : (await _fetchFlashcards(
            collectionId: collectionId,
            deckId: deckId,
          )).where(isActive).toList();

    return _takeSessionCards(retryCards, fillerCards, sessionCardLimit);
  }

  /// Cartes ratées lors de la dernière révision : un résultat `again` remet
  /// `repetitions` à zéro et incrémente `lapses`, donc `repetitions == 0` avec
  /// au moins un `lapse` identifie exactement les cartes dont la dernière
  /// réponse était fausse. Une carte jamais révisée n'a aucun `lapse`.
  Future<List<FlashcardRecord>> _fetchFailedFlashcards({
    String? collectionId,
    String? deckId,
  }) async {
    final query = _db.select(_db.flashcards)
      ..where(
        (table) =>
            table.repetitions.equals(0) & table.lapses.isBiggerThanValue(0),
      );
    if (collectionId != null) {
      query.where((table) => table.collectionId.equals(collectionId));
    }
    if (deckId != null) {
      query.where((table) => table.deckId.equals(deckId));
    }
    return (await query.get()).map(_toFlashcardRecord).toList();
  }

  /// Compose la session : les cartes ratées à la session précédente d'abord,
  /// puis les cartes à réviser, sans jamais dépasser la limite choisie. Le
  /// rattrapage occupe au plus la moitié de la session pour que de nouvelles
  /// cartes passent même après une série d'échecs ; les cartes ratées en trop
  /// attendent la session suivante, sauf s'il n'y a rien d'autre à réviser.
  List<FlashcardRecord> _takeSessionCards(
    Iterable<FlashcardRecord> retryCards,
    Iterable<FlashcardRecord> fillerCards,
    int sessionCardLimit,
  ) {
    int byImportOrder(FlashcardRecord a, FlashcardRecord b) {
      final byCreatedAt = a.createdAt.compareTo(b.createdAt);
      if (byCreatedAt != 0) {
        return byCreatedAt;
      }
      return a.id.compareTo(b.id);
    }

    List<FlashcardRecord> sorted(Iterable<FlashcardRecord> cards) {
      return [...cards]..sort(byImportOrder);
    }

    // Les cartes ratées passent de la plus ancienne à la plus récente : une
    // carte reportée faute de place ouvre la session suivante, avant les échecs
    // survenus depuis, et ne peut donc pas rester indéfiniment en attente.
    List<FlashcardRecord> sortedByOldestFailure(
      Iterable<FlashcardRecord> cards,
    ) {
      return [...cards]..sort((a, b) {
        final byFailure = (a.lastReviewedAt ?? a.createdAt).compareTo(
          b.lastReviewedAt ?? b.createdAt,
        );
        return byFailure != 0 ? byFailure : byImportOrder(a, b);
      });
    }

    final effectiveLimit = math.max(1, sessionCardLimit);
    final sortedRetryCards = sortedByOldestFailure(retryCards);
    final retryQuota = math.max(1, effectiveLimit ~/ 2);
    final promotedRetryCards = sortedRetryCards.take(retryQuota).toList();
    final deferredRetryIds = sortedRetryCards
        .skip(retryQuota)
        .map((card) => card.id)
        .toSet();

    final sessionCards = <FlashcardRecord>[];
    final selectedIds = <String>{};
    for (final card in [
      ...promotedRetryCards,
      ...sorted(
        fillerCards,
      ).where((card) => !deferredRetryIds.contains(card.id)),
      // Filet de sécurité : si le rattrapage est le seul contenu disponible,
      // il remplit la session plutôt que de la laisser incomplète.
      ...sortedRetryCards,
    ]) {
      if (selectedIds.add(card.id)) {
        sessionCards.add(card);
      }
      if (sessionCards.length >= effectiveLimit) {
        break;
      }
    }

    return sessionCards;
  }

  StudyCard _mapStudyCard(FlashcardRecord card, {TestMode? forcedMode}) {
    return StudyCard(
      id: card.id,
      collectionId: card.collectionId,
      deckId: card.deckId,
      question: card.question,
      correctAnswer: card.correctAnswer,
      wrongAnswers: card.wrongAnswers,
      hint: card.hint,
      explanation: card.explanation,
      currentTestMode: _resolveMode(card, forcedMode),
      allowedTestModes: card.allowedTestModes,
      clozeText: card.clozeText,
      clozeAnswers: card.clozeAnswers,
      clozeWordBank: card.clozeWordBank,
      acceptedAnswers: card.acceptedAnswers,
      level: card.level,
      progressDots: math.max(3, math.min(6, card.repetitions + 3)),
    );
  }

  /// Sans mode imposé, la carte est présentée dans le mode que sa progression
  /// lui a attribué : le QCM au début, des modes de rappel de plus en plus
  /// exigeants à mesure qu'elle est réussie.
  TestMode _resolveMode(FlashcardRecord card, TestMode? forcedMode) {
    final allowed = card.allowedTestModes;
    final requested = forcedMode ?? card.currentTestMode;
    if (allowed.contains(requested)) {
      return requested;
    }
    // Un mode indisponible ne dégrade pas la session : on retombe sur le mode
    // le plus proche que la carte sait jouer.
    if (requested == TestMode.cloze && allowed.contains(TestMode.freeText)) {
      return TestMode.freeText;
    }
    if (allowed.contains(TestMode.classicFlashcard)) {
      return TestMode.classicFlashcard;
    }
    return allowed.isNotEmpty ? allowed.first : TestMode.classicFlashcard;
  }

  // ---------------------------------------------------------------------
  // Agrégats métier
  // ---------------------------------------------------------------------

  CollectionListItem _buildCollectionListItem(
    CollectionRecord collection,
    List<FlashcardRecord> flashcards,
    int errorCount,
    DateTime now,
  ) {
    return CollectionListItem(
      id: collection.id,
      name: collection.name,
      description: collection.description,
      icon: collection.icon,
      totalCards: flashcards.length,
      cardsDone: flashcards.where((card) => card.repetitions > 0).length,
      dueCards: flashcards
          .where((card) => !_isDueInFuture(card.dueAt, now))
          .length,
      color: collection.color,
      createdAt: collection.createdAt,
      updatedAt: collection.updatedAt,
      errorCount: errorCount,
      isDisabled: collection.isDisabled,
    );
  }

  DeckListItem _buildDeckListItem(
    DeckRecord deck,
    List<FlashcardRecord> flashcards,
    DateTime now,
  ) {
    final cardsDone = flashcards.where((card) => card.repetitions > 0).length;
    final dueCards = flashcards
        .where((card) => !_isDueInFuture(card.dueAt, now))
        .length;
    final masteredCards = flashcards.where((card) => card.mastered).length;
    final totalCards = flashcards.length;
    final status = dueCards > 0
        ? DeckStatus.dues
        : (totalCards > 0 && masteredCards == totalCards)
        ? DeckStatus.maitrise
        : DeckStatus.nouveau;

    return DeckListItem(
      id: deck.id,
      collectionId: deck.collectionId,
      name: deck.name,
      icon: deck.icon,
      difficulty: deck.difficulty,
      totalCards: totalCards,
      cardsDone: cardsDone,
      dueCards: dueCards,
      progress: totalCards == 0 ? 0 : cardsDone / totalCards,
      status: status,
      createdAt: deck.createdAt,
      updatedAt: deck.updatedAt,
      isDisabled: deck.isDisabled,
    );
  }

  /// Retire les cartes d'un deck désactivé pour qu'elles ne comptent plus dans
  /// les sessions ni dans les totaux « à revoir ». Les journaux de révision ne
  /// sont jamais filtrés ainsi.
  List<FlashcardRecord> _excludeDisabledDeckCards(
    List<FlashcardRecord> flashcards,
    List<DeckRecord> decks,
  ) {
    final disabledDeckIds = {
      for (final deck in decks)
        if (deck.isDisabled) deck.id,
    };
    if (disabledDeckIds.isEmpty) {
      return flashcards;
    }
    return flashcards
        .where((card) => !disabledDeckIds.contains(card.deckId))
        .toList();
  }

  List<FlashcardRecord> _excludeUnavailableCards(
    List<FlashcardRecord> flashcards, {
    required List<CollectionRecord> collections,
    required List<DeckRecord> decks,
  }) {
    final disabledCollectionIds = {
      for (final collection in collections)
        if (collection.isDisabled) collection.id,
    };
    final disabledDeckIds = {
      for (final deck in decks)
        if (deck.isDisabled) deck.id,
    };
    if (disabledCollectionIds.isEmpty && disabledDeckIds.isEmpty) {
      return flashcards;
    }
    return flashcards
        .where(
          (card) =>
              !disabledCollectionIds.contains(card.collectionId) &&
              !disabledDeckIds.contains(card.deckId),
        )
        .toList();
  }

  StatisticsOverview _buildStatisticsOverview(
    List<CollectionRecord> collections,
    List<FlashcardRecord> flashcards,
    _ReviewTotals totals,
    List<ReviewLogRecord> logs,
    DateTime now,
  ) {
    final localNow = now.toLocal();
    final heatmap = List.generate(14, (index) {
      final date = DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
      ).subtract(Duration(days: 13 - index));
      final count = totals.dayCounts[date] ?? 0;
      return HeatmapCell(
        label: '${date.day}/${date.month}',
        count: count,
        isActive: count > 0,
      );
    });

    final levelCounts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0};
    for (final card in flashcards) {
      levelCounts.update(card.level, (value) => value + 1, ifAbsent: () => 1);
    }
    final maxLevel = levelCounts.values.fold<int>(1, math.max);

    final trend = List.generate(14, (index) {
      final date = DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
      ).subtract(Duration(days: 13 - index));
      final dayLogs = logs.where((log) {
        final created = log.createdAt.toLocal();
        return created.year == date.year &&
            created.month == date.month &&
            created.day == date.day;
      }).toList();
      final correct = dayLogs.where((log) => log.wasCorrect).length;
      return StatisticsTrendPoint(
        label: '${date.day}/${date.month}',
        reviewCount: dayLogs.length,
        successRate: dayLogs.isEmpty ? 0 : correct / dayLogs.length,
      );
    });

    final collectionNames = {
      for (final collection in collections) collection.id: collection.name,
    };
    final collectionGroups = <String, List<ReviewLogRecord>>{};
    for (final log in logs) {
      collectionGroups.putIfAbsent(log.collectionId, () => []).add(log);
    }
    final collectionProgress = collectionGroups.entries.map((entry) {
      final correct = entry.value.where((log) => log.wasCorrect).length;
      return CollectionStatistics(
        name: collectionNames[entry.key] ?? 'Collection supprimée',
        reviewCount: entry.value.length,
        successRate: correct / entry.value.length,
      );
    }).toList()..sort((a, b) => b.reviewCount.compareTo(a.reviewCount));

    final modeGroups = <TestMode, List<ReviewLogRecord>>{};
    for (final log in logs) {
      modeGroups.putIfAbsent(log.testMode, () => []).add(log);
    }
    final modeProgress = modeGroups.entries.map((entry) {
      final correct = entry.value.where((log) => log.wasCorrect).length;
      return ModeStatistics(
        mode: entry.key,
        reviewCount: entry.value.length,
        successRate: correct / entry.value.length,
      );
    }).toList()..sort((a, b) => b.reviewCount.compareTo(a.reviewCount));

    final cardGroups = <String, List<ReviewLogRecord>>{};
    for (final log in logs) {
      cardGroups.putIfAbsent(log.flashcardId, () => []).add(log);
    }
    final cardsById = {for (final card in flashcards) card.id: card};
    final difficultCards =
        cardGroups.entries
            .map((entry) {
              final card = cardsById[entry.key];
              final errors = entry.value.where((log) => !log.wasCorrect).length;
              final correct = entry.value.where((log) => log.wasCorrect).length;
              return DifficultCardStatistics(
                question: card?.question ?? 'Carte supprimée',
                errorCount: errors,
                reviewCount: entry.value.length,
                successRate: correct / entry.value.length,
              );
            })
            .where((item) => item.errorCount > 0)
            .toList()
          ..sort((a, b) => b.errorCount.compareTo(a.errorCount));

    LevelProgress level(
      int value,
      String title,
      String subtitle,
      IconData icon,
    ) {
      return LevelProgress(
        level: value,
        title: title,
        subtitle: subtitle,
        count: levelCounts[value] ?? 0,
        progress: (levelCounts[value] ?? 0) / maxLevel,
        icon: icon,
      );
    }

    return StatisticsOverview(
      streakDays: _calculateStreak(totals.dayCounts.keys, now: now),
      totalReviews: totals.total,
      successRate: totals.successRate,
      studyDays: totals.dayCounts.length,
      heatmap: heatmap,
      levelProgress: [
        level(
          1,
          'Basique',
          'Fondations et reconnaissance',
          Icons.visibility_rounded,
        ),
        level(2, 'Intermédiaire', 'Compréhension guidée', Icons.tune_rounded),
        level(3, 'Actif', 'Rappel actif et reformulation', Icons.bolt_rounded),
        level(
          4,
          'Avancé',
          'Maîtrise contextuelle',
          Icons.psychology_alt_rounded,
        ),
      ],
      successTrend: trend,
      collectionProgress: collectionProgress,
      modeProgress: modeProgress,
      difficultCards: difficultCards.take(5).toList(),
    );
  }

  int _calculateStreak(Iterable<DateTime> studyDays, {required DateTime now}) {
    final daySet = studyDays.toSet();
    if (daySet.isEmpty) {
      return 0;
    }

    final localNow = now.toLocal();
    var cursor = DateTime(localNow.year, localNow.month, localNow.day);
    var streak = 0;
    while (daySet.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  bool _isDueInFuture(DateTime dueAt, DateTime now) => dueAt.isAfter(now);

  // ---------------------------------------------------------------------
  // Conversions base locale ↔ domaine
  // ---------------------------------------------------------------------

  CollectionRecord _toCollectionRecord(Collection row) {
    return CollectionRecord(
      id: row.id,
      name: row.name,
      description: row.description,
      icon: row.icon,
      color: row.color,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isDisabled: row.isDisabled,
    );
  }

  DeckRecord _toDeckRecord(Deck row) {
    return DeckRecord(
      id: row.id,
      collectionId: row.collectionId,
      name: row.name,
      icon: row.icon,
      difficulty: row.difficulty,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isDisabled: row.isDisabled,
    );
  }

  FlashcardRecord _toFlashcardRecord(Flashcard row) {
    return FlashcardRecord(
      id: row.id,
      collectionId: row.collectionId,
      deckId: row.deckId,
      question: row.question,
      correctAnswer: row.correctAnswer,
      answer: row.answer,
      wrongAnswers: row.wrongAnswers,
      hint: row.hint,
      explanation: row.explanation,
      currentTestMode: row.currentTestMode,
      allowedTestModes: row.allowedTestModes,
      lastTestMode: row.lastTestMode,
      modeHistory: row.modeHistory,
      clozeText: row.clozeText,
      clozeAnswers: row.clozeAnswers,
      clozeWordBank: row.clozeWordBank,
      acceptedAnswers: row.acceptedAnswers,
      source: row.source,
      difficulty: row.difficulty,
      level: row.level,
      tags: row.tags,
      dueAt: row.dueAt,
      lastReviewedAt: row.lastReviewedAt,
      intervalDays: row.intervalDays,
      easeFactor: row.easeFactor,
      repetitions: row.repetitions,
      lapses: row.lapses,
      mastered: row.mastered,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  FlashcardSummary _toSummary(FlashcardRecord card) {
    return FlashcardSummary(
      id: card.id,
      deckId: card.deckId,
      collectionId: card.collectionId,
      question: card.question,
      correctAnswer: card.correctAnswer,
    );
  }

  CollectionsCompanion _collectionCompanion(CollectionRecord collection) {
    return CollectionsCompanion.insert(
      id: collection.id,
      name: collection.name,
      description: collection.description,
      icon: collection.icon,
      color: collection.color,
      isDisabled: Value(collection.isDisabled),
      createdAt: collection.createdAt,
      updatedAt: collection.updatedAt,
    );
  }

  DecksCompanion _deckCompanion(DeckRecord deck) {
    return DecksCompanion.insert(
      id: deck.id,
      collectionId: deck.collectionId,
      name: deck.name,
      icon: deck.icon,
      difficulty: deck.difficulty,
      isDisabled: Value(deck.isDisabled),
      createdAt: deck.createdAt,
      updatedAt: deck.updatedAt,
    );
  }

  FlashcardsCompanion _flashcardCompanion(FlashcardRecord card) {
    return FlashcardsCompanion.insert(
      id: card.id,
      collectionId: card.collectionId,
      deckId: card.deckId,
      question: card.question,
      correctAnswer: card.correctAnswer,
      answer: Value(card.answer),
      wrongAnswers: card.wrongAnswers,
      hint: Value(card.hint),
      explanation: Value(card.explanation),
      currentTestMode: card.currentTestMode,
      allowedTestModes: card.allowedTestModes,
      lastTestMode: Value(card.lastTestMode),
      modeHistory: card.modeHistory,
      clozeText: Value(card.clozeText),
      clozeAnswers: card.clozeAnswers,
      clozeWordBank: card.clozeWordBank,
      acceptedAnswers: card.acceptedAnswers,
      source: Value(card.source),
      difficulty: Value(card.difficulty),
      level: card.level,
      tags: card.tags,
      dueAt: card.dueAt,
      lastReviewedAt: Value(card.lastReviewedAt),
      intervalDays: card.intervalDays,
      easeFactor: card.easeFactor,
      repetitions: card.repetitions,
      lapses: card.lapses,
      mastered: card.mastered,
      createdAt: card.createdAt,
      updatedAt: card.updatedAt,
    );
  }

  ReviewLogsCompanion _reviewLogCompanion(ReviewLogRecord log) {
    return ReviewLogsCompanion.insert(
      id: log.id,
      flashcardId: log.flashcardId,
      collectionId: log.collectionId,
      deckId: log.deckId,
      reviewResult: log.reviewResult,
      testMode: log.testMode,
      wasCorrect: log.wasCorrect,
      createdAt: log.createdAt,
      scheduledDueAt: log.scheduledDueAt,
    );
  }

  CollectionRecord _copyCollection(
    CollectionRecord collection, {
    String? icon,
    bool? isDisabled,
  }) {
    return CollectionRecord(
      id: collection.id,
      name: collection.name,
      description: collection.description,
      icon: icon ?? collection.icon,
      color: collection.color,
      createdAt: collection.createdAt,
      updatedAt: DateTime.now(),
      isDisabled: isDisabled ?? collection.isDisabled,
    );
  }

  static _ReviewTotals _toReviewTotals(List<QueryRow> rows) {
    var total = 0;
    var correct = 0;
    final dayCounts = <DateTime, int>{};

    for (final row in rows) {
      final rowTotal = row.read<int>('total');
      total += rowTotal;
      correct += row.read<int?>('correct') ?? 0;
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('day'),
      ).toLocal();
      final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
      dayCounts.update(
        day,
        (value) => value + rowTotal,
        ifAbsent: () => rowTotal,
      );
    }

    return _ReviewTotals(total: total, correct: correct, dayCounts: dayCounts);
  }

  T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) predicate) {
    for (final item in items) {
      if (predicate(item)) {
        return item;
      }
    }
    return null;
  }

  /// Les compteurs « à revoir » basculent quand une échéance est franchie,
  /// sans qu'aucune donnée n'ait changé : il faut donc une horloge.
  Stream<DateTime> _clockStream({
    Duration interval = const Duration(minutes: 1),
  }) async* {
    yield DateTime.now();
    yield* Stream.periodic(interval, (_) => DateTime.now());
  }
}

class _ReviewTotals {
  const _ReviewTotals({
    required this.total,
    required this.correct,
    required this.dayCounts,
  });

  final int total;
  final int correct;
  final Map<DateTime, int> dayCounts;

  double get successRate => total == 0 ? 0 : correct / total;
}
