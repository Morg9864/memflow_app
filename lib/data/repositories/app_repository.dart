import 'dart:math';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/models.dart';
import '../../domain/services/card_mode_service.dart';
import '../../domain/services/spaced_repetition_service.dart';
import '../../domain/services/sync_service.dart';
import '../local/database.dart';

class AppRepository {
  AppRepository({
    required AppDatabase database,
    required SpacedRepetitionService spacedRepetitionService,
    required CardModeService cardModeService,
    required SyncService syncService,
  })  : _database = database,
        _spacedRepetitionService = spacedRepetitionService,
        _cardModeService = cardModeService,
        _syncService = syncService;

  final AppDatabase _database;
  final SpacedRepetitionService _spacedRepetitionService;
  final CardModeService _cardModeService;
  final SyncService _syncService;
  final Uuid _uuid = const Uuid();

  Stream<List<CollectionListItem>> watchCollections({String search = ''}) {
    final lowered = search.trim().toLowerCase();
    return _database.customSelect(
      '''
      SELECT
        c.id,
        c.name,
        c.description,
        c.icon,
        c.total_cards,
        c.mastered_percentage,
        c.color,
        c.created_at,
        c.updated_at,
        (
          SELECT COUNT(*)
          FROM flashcards f
          WHERE f.collection_id = c.id
            AND f.due_at <= ?
        ) AS due_cards
      FROM collections c
      WHERE ? = '' OR lower(c.name) LIKE ?
      ORDER BY c.name
      ''',
      variables: [
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withString(lowered),
        Variable.withString('%$lowered%'),
      ],
      readsFrom: {_database.collections, _database.flashcards},
    ).watch().map(
          (rows) => rows
              .map(
                (row) => CollectionListItem(
                  id: row.read<String>('id'),
                  name: row.read<String>('name'),
                  description: row.read<String>('description'),
                  icon: row.read<String>('icon'),
                  totalCards: row.read<int>('total_cards'),
                  masteredPercentage: row.read<double>('mastered_percentage'),
                  color: row.read<int>('color'),
                  createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
                  updatedAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('updated_at')),
                  dueCards: row.read<int>('due_cards'),
                ),
              )
              .toList(),
        );
  }

  Stream<CollectionListItem?> watchCollection(String id) {
    return _database.customSelect(
      '''
      SELECT
        c.id,
        c.name,
        c.description,
        c.icon,
        c.total_cards,
        c.mastered_percentage,
        c.color,
        c.created_at,
        c.updated_at,
        (
          SELECT COUNT(*)
          FROM flashcards f
          WHERE f.collection_id = c.id
            AND f.due_at <= ?
        ) AS due_cards
      FROM collections c
      WHERE c.id = ?
      LIMIT 1
      ''',
      variables: [
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withString(id),
      ],
      readsFrom: {_database.collections, _database.flashcards},
    ).watchSingleOrNull().map(
          (row) => row == null
              ? null
              : CollectionListItem(
                  id: row.read<String>('id'),
                  name: row.read<String>('name'),
                  description: row.read<String>('description'),
                  icon: row.read<String>('icon'),
                  totalCards: row.read<int>('total_cards'),
                  masteredPercentage: row.read<double>('mastered_percentage'),
                  color: row.read<int>('color'),
                  createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
                  updatedAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('updated_at')),
                  dueCards: row.read<int>('due_cards'),
                ),
        );
  }

  Stream<List<DeckListItem>> watchDecksForCollection(String collectionId) {
    return _database.customSelect(
      '''
      SELECT
        d.id,
        d.collection_id,
        d.name,
        d.icon,
        d.difficulty,
        d.total_cards,
        d.due_cards,
        d.progress,
        d.status,
        d.created_at,
        d.updated_at
      FROM decks d
      WHERE d.collection_id = ?
      ORDER BY d.created_at
      ''',
      variables: [Variable.withString(collectionId)],
      readsFrom: {_database.decks},
    ).watch().map(
          (rows) => rows
              .map(
                (row) => DeckListItem(
                  id: row.read<String>('id'),
                  collectionId: row.read<String>('collection_id'),
                  name: row.read<String>('name'),
                  icon: row.read<String>('icon'),
                  difficulty: DeckDifficulty.values
                      .firstWhere((value) => value.name == row.read<String>('difficulty')),
                  totalCards: row.read<int>('total_cards'),
                  dueCards: row.read<int>('due_cards'),
                  progress: row.read<double>('progress'),
                  status: DeckStatus.values
                      .firstWhere((value) => value.name == row.read<String>('status')),
                  createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
                  updatedAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('updated_at')),
                ),
              )
              .toList(),
        );
  }

  Stream<HomeStats> watchHomeStats() {
    return _database.customSelect(
      'SELECT 1 AS trigger',
      readsFrom: {_database.flashcards, _database.reviewLogs},
    ).watchSingle().asyncMap((_) => _loadHomeStats());
  }

  Future<HomeStats> _loadHomeStats() async {
    final dueRow = await _database.customSelect(
      'SELECT COUNT(*) AS c FROM flashcards WHERE due_at <= ?',
      variables: [Variable.withInt(DateTime.now().millisecondsSinceEpoch)],
    ).getSingle();
    final reviews = await _database.select(_database.reviewLogs).get();
    final streak = _calculateStreak(reviews.map((log) => log.createdAt).toList());
    final successCount = reviews.where((log) => log.wasCorrect).length;
    final successRate = reviews.isEmpty ? 0.0 : successCount / reviews.length;

    return HomeStats(
      streakDays: streak,
      successRate: successRate,
      dueCards: dueRow.read<int>('c'),
      totalCardsSeen: reviews.length,
    );
  }

  Stream<StatisticsOverview> watchStatisticsOverview() {
    return _database.customSelect(
      'SELECT 1 AS trigger',
      readsFrom: {_database.reviewLogs, _database.flashcards},
    ).watchSingle().asyncMap((_) => _loadStatisticsOverview());
  }

  Future<StatisticsOverview> _loadStatisticsOverview() async {
    final reviews = await _database.select(_database.reviewLogs).get();
    final flashcards = await _database.select(_database.flashcards).get();
    final streak = _calculateStreak(reviews.map((log) => log.createdAt).toList());
    final successCount = reviews.where((log) => log.wasCorrect).length;
    final successRate = reviews.isEmpty ? 0.0 : successCount / reviews.length;
    final studyDayMap = <DateTime, int>{};
    for (final review in reviews) {
      final key = DateTime(review.createdAt.year, review.createdAt.month, review.createdAt.day);
      studyDayMap.update(key, (value) => value + 1, ifAbsent: () => 1);
    }

    final now = DateTime.now();
    final heatmap = List.generate(4, (weekIndex) {
      return List.generate(7, (dayIndex) {
        final date = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: (3 - weekIndex) * 7 + (6 - dayIndex)));
        final key = DateTime(date.year, date.month, date.day);
        final count = studyDayMap[key] ?? 0;
        return HeatmapCell(
          label: '${key.day}/${key.month}',
          count: count,
          isActive: count > 0,
        );
      });
    });

    final levelCounts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0};
    for (final card in flashcards) {
      levelCounts.update(card.level, (value) => value + 1, ifAbsent: () => 1);
    }
    final maxLevel = levelCounts.values.fold<int>(1, max);
    final levelProgress = [
      LevelProgress(
        level: 1,
        title: 'Basique',
        subtitle: 'Fondations et reconnaissance',
        count: levelCounts[1] ?? 0,
        progress: (levelCounts[1] ?? 0) / maxLevel,
        icon: Icons.visibility_rounded,
      ),
      LevelProgress(
        level: 2,
        title: 'Intermédiaire',
        subtitle: 'Compréhension guidée',
        count: levelCounts[2] ?? 0,
        progress: (levelCounts[2] ?? 0) / maxLevel,
        icon: Icons.tune_rounded,
      ),
      LevelProgress(
        level: 3,
        title: 'Actif',
        subtitle: 'Rappel actif et reformulation',
        count: levelCounts[3] ?? 0,
        progress: (levelCounts[3] ?? 0) / maxLevel,
        icon: Icons.bolt_rounded,
      ),
      LevelProgress(
        level: 4,
        title: 'Avancé',
        subtitle: 'Maîtrise contextuelle',
        count: levelCounts[4] ?? 0,
        progress: (levelCounts[4] ?? 0) / maxLevel,
        icon: Icons.psychology_alt_rounded,
      ),
    ];

    return StatisticsOverview(
      streakDays: streak,
      totalReviews: reviews.length,
      successRate: successRate,
      studyDays: studyDayMap.length,
      heatmap: heatmap,
      levelProgress: levelProgress,
    );
  }

  int _calculateStreak(List<DateTime> timestamps) {
    final days = timestamps
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) {
      return 0;
    }

    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    var streak = 0;
    final daySet = days.toSet();
    while (daySet.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<StudySessionState> startStudySession({
    String? collectionId,
    String? deckId,
  }) async {
    final now = DateTime.now();
    final cards = await _loadSessionCards(
      collectionId: collectionId,
      deckId: deckId,
      now: now,
    );

    if (cards.isEmpty) {
      throw StateError('Aucune carte disponible pour cette session.');
    }

    String title = 'Révision';
    if (deckId != null) {
      final deck = await (_database.select(_database.decks)
            ..where((table) => table.id.equals(deckId)))
          .getSingle();
      title = deck.name;
    } else if (collectionId != null) {
      final collection = await (_database.select(_database.collections)
            ..where((table) => table.id.equals(collectionId)))
          .getSingle();
      title = collection.name;
    }

    return StudySessionState(
      deckTitle: title,
      collectionId: collectionId,
      deckId: deckId,
      cards: cards.map(_mapStudyCard).toList(),
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

  Future<List<Flashcard>> _loadSessionCards({
    required String? collectionId,
    required String? deckId,
    required DateTime now,
  }) async {
    final predicate = [
      if (collectionId != null) _database.flashcards.collectionId.equals(collectionId),
      if (deckId != null) _database.flashcards.deckId.equals(deckId),
    ];

    Future<List<Flashcard>> load(bool onlyDue) {
      final query = _database.select(_database.flashcards)
        ..orderBy([(table) => OrderingTerm(expression: table.dueAt)])
        ..limit(12);
      if (predicate.isNotEmpty || onlyDue) {
        query.where((table) {
          Expression<bool> expression = const Constant(true);
          for (final condition in predicate) {
            expression = expression & condition;
          }
          if (onlyDue) {
            expression =
                expression & table.dueAt.isSmallerOrEqualValue(now.millisecondsSinceEpoch);
          }
          return expression;
        });
      }
      return query.get();
    }

    final dueCards = await load(true);
    if (dueCards.isNotEmpty) {
      return dueCards;
    }
    return load(false);
  }

  StudyCard _mapStudyCard(Flashcard card) {
    return StudyCard(
      id: card.id,
      collectionId: card.collectionId,
      deckId: card.deckId,
      question: card.question,
      correctAnswer: card.correctAnswer,
      wrongAnswers: card.wrongAnswers,
      hint: card.hint,
      explanation: card.explanation,
      currentTestMode: _effectiveMode(card),
      allowedTestModes: card.allowedTestModes,
      clozeText: card.clozeText,
      acceptedAnswers: card.acceptedAnswers,
      level: card.level,
      progressDots: max(3, min(6, card.repetitions + 3)),
    );
  }

  TestMode _effectiveMode(Flashcard card) {
    return switch (card.currentTestMode) {
      TestMode.ordering || TestMode.matching => TestMode.classicFlashcard,
      _ => card.currentTestMode,
    };
  }

  Future<void> submitReview({
    required String cardId,
    required ReviewResult reviewResult,
    required bool wasCorrect,
  }) async {
    final now = DateTime.now();
    final card = await (_database.select(_database.flashcards)
          ..where((table) => table.id.equals(cardId)))
        .getSingle();
    final scheduleUpdate = _spacedRepetitionService.applyReview(
      card,
      reviewResult,
      now: now,
    );
    final nextMode = _cardModeService.nextMode(card, reviewResult);
    final reviewLog = ReviewLogsCompanion.insert(
      id: _uuid.v4(),
      flashcardId: card.id,
      collectionId: card.collectionId,
      deckId: card.deckId,
      reviewResult: reviewResult,
      testMode: card.currentTestMode,
      wasCorrect: wasCorrect,
      createdAt: now,
      scheduledDueAt: card.dueAt,
    );

    await _database.transaction(() async {
      await _database.update(_database.flashcards).replace(
            card.copyWith(
              currentTestMode: nextMode,
              lastTestMode: Value(card.currentTestMode),
              modeHistory: _cardModeService.updatedModeHistory(card, nextMode),
              dueAt: scheduleUpdate.dueAt,
              lastReviewedAt: Value(scheduleUpdate.lastReviewedAt),
              intervalDays: scheduleUpdate.intervalDays,
              easeFactor: scheduleUpdate.easeFactor,
              repetitions: scheduleUpdate.repetitions,
              lapses: scheduleUpdate.lapses,
              mastered: scheduleUpdate.mastered,
              updatedAt: now,
            ),
          );
      await _database.into(_database.reviewLogs).insert(reviewLog);
      await refreshDerivedData(
        collectionId: card.collectionId,
        deckId: card.deckId,
      );
    });

    final updatedCard = await (_database.select(_database.flashcards)
          ..where((table) => table.id.equals(cardId)))
        .getSingle();
    final deck = await (_database.select(_database.decks)
          ..where((table) => table.id.equals(card.deckId)))
        .getSingle();
    final collection = await (_database.select(_database.collections)
          ..where((table) => table.id.equals(card.collectionId)))
        .getSingle();
    final savedReviewLog = await (_database.select(_database.reviewLogs)
          ..where((table) => table.id.equals(reviewLog.id.value)))
        .getSingle();

    await _syncService.enqueueUpsert(
      SyncEntityType.flashcard,
      updatedCard.id,
      flashcardPayload(updatedCard),
    );
    await _syncService.enqueueUpsert(
      SyncEntityType.deck,
      deck.id,
      deckPayload(deck),
    );
    await _syncService.enqueueUpsert(
      SyncEntityType.collection,
      collection.id,
      collectionPayload(collection),
    );
    await _syncService.enqueueUpsert(
      SyncEntityType.reviewLog,
      savedReviewLog.id,
      reviewLogPayload(savedReviewLog),
    );
    _syncService.scheduleSync();
  }

  Future<void> importCards(CsvImportPreview preview) async {
    if (preview.cards.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final collectionsByName = {
      for (final collection in await _database.select(_database.collections).get())
        collection.name.toLowerCase(): collection,
    };
    final decksByKey = {
      for (final deck in await _database.select(_database.decks).get())
        '${deck.collectionId}:${deck.name.toLowerCase()}': deck,
    };
    final touchedCollectionIds = <String>{};
    final touchedDeckIds = <String>{};
    final createdCardIds = <String>{};

    await _database.transaction(() async {
      for (final draft in preview.cards) {
        final collectionKey = draft.collection.toLowerCase();
        var collection = collectionsByName[collectionKey];
        if (collection == null) {
          final collectionId = _slugify(draft.collection);
          final companion = CollectionsCompanion.insert(
            id: collectionId,
            name: draft.collection,
            description: 'Import CSV',
            icon: '📚',
            totalCards: 0,
            masteredPercentage: 0,
            color: 0xFFE8792F,
            createdAt: now,
            updatedAt: now,
          );
          await _database.into(_database.collections).insert(companion);
          collection = await (_database.select(_database.collections)
                ..where((table) => table.id.equals(collectionId)))
              .getSingle();
          collectionsByName[collectionKey] = collection;
        }

        final deckKey = '${collection.id}:${draft.deck.toLowerCase()}';
        var deck = decksByKey[deckKey];
        if (deck == null) {
          final deckId = _slugify('${collection.id}-${draft.deck}');
          final companion = DecksCompanion.insert(
            id: deckId,
            collectionId: collection.id,
            name: draft.deck,
            icon: '🗂️',
            difficulty: draft.difficulty,
            totalCards: 0,
            dueCards: 0,
            progress: 0,
            status: DeckStatus.nouveau,
            createdAt: now,
            updatedAt: now,
          );
          await _database.into(_database.decks).insert(companion);
          deck =
              await (_database.select(_database.decks)..where((table) => table.id.equals(deckId)))
                  .getSingle();
          decksByKey[deckKey] = deck;
        }

        final cardId = _uuid.v4();
        await _database.into(_database.flashcards).insert(
              FlashcardsCompanion.insert(
                id: cardId,
                collectionId: collection.id,
                deckId: deck.id,
                question: draft.question,
                correctAnswer: draft.correctAnswer,
                answer: Value(draft.correctAnswer),
                wrongAnswers: draft.wrongAnswers,
                hint: Value(draft.hint),
                explanation: Value(draft.explanation),
                currentTestMode: TestMode.multipleChoice,
                allowedTestModes: draft.allowedTestModes,
                lastTestMode: const Value(null),
                modeHistory: const [TestMode.multipleChoice],
                clozeText: Value(draft.clozeText),
                acceptedAnswers: draft.acceptedAnswers,
                source: Value(draft.source),
                difficulty: Value(draft.difficulty),
                level: draft.level,
                tags: draft.tags,
                dueAt: now,
                lastReviewedAt: const Value(null),
                intervalDays: 0,
                easeFactor: 2.5,
                repetitions: 0,
                lapses: 0,
                mastered: false,
                createdAt: now,
                updatedAt: now,
              ),
            );
        createdCardIds.add(cardId);
        touchedCollectionIds.add(collection.id);
        touchedDeckIds.add(deck.id);
      }
    });

    for (final deckId in touchedDeckIds) {
      await refreshDerivedData(deckId: deckId);
    }
    for (final collectionId in touchedCollectionIds) {
      await refreshDerivedData(collectionId: collectionId);
    }

    if (createdCardIds.isNotEmpty) {
      final cards = await (_database.select(_database.flashcards)
            ..where((table) => table.id.isIn(createdCardIds)))
          .get();
      for (final card in cards) {
        await _syncService.enqueueUpsert(
          SyncEntityType.flashcard,
          card.id,
          flashcardPayload(card),
        );
      }
    }

    for (final deckId in touchedDeckIds) {
      final deck = await (_database.select(_database.decks)
            ..where((table) => table.id.equals(deckId)))
          .getSingle();
      await _syncService.enqueueUpsert(
        SyncEntityType.deck,
        deck.id,
        deckPayload(deck),
      );
    }

    for (final collectionId in touchedCollectionIds) {
      final collection = await (_database.select(_database.collections)
            ..where((table) => table.id.equals(collectionId)))
          .getSingle();
      await _syncService.enqueueUpsert(
        SyncEntityType.collection,
        collection.id,
        collectionPayload(collection),
      );
    }

    _syncService.scheduleSync();
  }

  Future<void> refreshDerivedData({
    String? collectionId,
    String? deckId,
  }) async {
    if (deckId != null) {
      final totalRow = await _database.customSelect(
        'SELECT COUNT(*) AS c FROM flashcards WHERE deck_id = ?',
        variables: [Variable.withString(deckId)],
      ).getSingle();
      final dueRow = await _database.customSelect(
        'SELECT COUNT(*) AS c FROM flashcards WHERE deck_id = ? AND due_at <= ?',
        variables: [
          Variable.withString(deckId),
          Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        ],
      ).getSingle();
      final masteredRow = await _database.customSelect(
        'SELECT COUNT(*) AS c FROM flashcards WHERE deck_id = ? AND mastered = 1',
        variables: [Variable.withString(deckId)],
      ).getSingle();
      final deck = await (_database.select(_database.decks)
            ..where((table) => table.id.equals(deckId)))
          .getSingle();
      final total = totalRow.read<int>('c');
      final due = dueRow.read<int>('c');
      final mastered = masteredRow.read<int>('c');
      final progress = total == 0 ? 0.0 : mastered / total;
      final status = due > 0
          ? DeckStatus.dues
          : progress >= 0.9
              ? DeckStatus.maitrise
              : DeckStatus.nouveau;
      await _database.update(_database.decks).replace(
            deck.copyWith(
              totalCards: total,
              dueCards: due,
              progress: progress,
              status: status,
              updatedAt: DateTime.now(),
            ),
          );
      collectionId ??= deck.collectionId;
    }

    if (collectionId != null) {
      final resolvedCollectionId = collectionId;
      final totalRow = await _database.customSelect(
        'SELECT COUNT(*) AS c FROM flashcards WHERE collection_id = ?',
        variables: [Variable.withString(resolvedCollectionId)],
      ).getSingle();
      final masteredRow = await _database.customSelect(
        'SELECT COUNT(*) AS c FROM flashcards WHERE collection_id = ? AND mastered = 1',
        variables: [Variable.withString(resolvedCollectionId)],
      ).getSingle();
      final collection = await (_database.select(_database.collections)
            ..where((table) => table.id.equals(resolvedCollectionId)))
          .getSingle();
      final total = totalRow.read<int>('c');
      final mastered = masteredRow.read<int>('c');
      final mastery = total == 0 ? 0.0 : mastered / total;
      await _database.update(_database.collections).replace(
            collection.copyWith(
              totalCards: total,
              masteredPercentage: mastery,
              updatedAt: DateTime.now(),
            ),
          );
    }
  }

  Future<void> refreshAllDerivedData() async {
    final decks = await _database.select(_database.decks).get();
    for (final deck in decks) {
      await refreshDerivedData(deckId: deck.id);
    }
  }

  /// Enqueues every local entity for an upsert. Used to claim pre-existing
  /// (anonymous) local data for an account the first time it signs in: the
  /// sync push then stamps each row with the user's id.
  Future<void> enqueueAllLocalEntities() async {
    final collections = await _database.select(_database.collections).get();
    for (final collection in collections) {
      await _syncService.enqueueUpsert(
        SyncEntityType.collection,
        collection.id,
        collectionPayload(collection),
      );
    }

    final decks = await _database.select(_database.decks).get();
    for (final deck in decks) {
      await _syncService.enqueueUpsert(
        SyncEntityType.deck,
        deck.id,
        deckPayload(deck),
      );
    }

    final cards = await _database.select(_database.flashcards).get();
    for (final card in cards) {
      await _syncService.enqueueUpsert(
        SyncEntityType.flashcard,
        card.id,
        flashcardPayload(card),
      );
    }

    final reviewLogs = await _database.select(_database.reviewLogs).get();
    for (final log in reviewLogs) {
      await _syncService.enqueueUpsert(
        SyncEntityType.reviewLog,
        log.id,
        reviewLogPayload(log),
      );
    }
  }

  Future<String> exportAllCardsCsv() async {
    final collections = await _database.select(_database.collections).get();
    final decks = await _database.select(_database.decks).get();
    final cards = await _database.select(_database.flashcards).get();

    final collectionMap = {for (final collection in collections) collection.id: collection.name};
    final deckMap = {for (final deck in decks) deck.id: deck.name};
    final rows = <List<String>>[
      const [
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
      ],
    ];

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
      ]);
    }

    return Csv(fieldDelimiter: ';').encode(rows);
  }

  Map<String, dynamic> collectionPayload(Collection collection) => {
        'id': collection.id,
        'name': collection.name,
        'description': collection.description,
        'icon': collection.icon,
        'total_cards': collection.totalCards,
        'mastered_percentage': collection.masteredPercentage,
        'color': collection.color,
        'created_at': collection.createdAt.toIso8601String(),
        'updated_at': collection.updatedAt.toIso8601String(),
      };

  Map<String, dynamic> deckPayload(Deck deck) => {
        'id': deck.id,
        'collection_id': deck.collectionId,
        'name': deck.name,
        'icon': deck.icon,
        'difficulty': deck.difficulty.name,
        'total_cards': deck.totalCards,
        'due_cards': deck.dueCards,
        'progress': deck.progress,
        'status': deck.status.name,
        'created_at': deck.createdAt.toIso8601String(),
        'updated_at': deck.updatedAt.toIso8601String(),
      };

  Map<String, dynamic> flashcardPayload(Flashcard card) => {
        'id': card.id,
        'collection_id': card.collectionId,
        'deck_id': card.deckId,
        'question': card.question,
        'correct_answer': card.correctAnswer,
        'answer': card.answer,
        'wrong_answers': card.wrongAnswers,
        'hint': card.hint,
        'explanation': card.explanation,
        'current_test_mode': card.currentTestMode.name,
        'allowed_test_modes': card.allowedTestModes.map((mode) => mode.name).toList(),
        'last_test_mode': card.lastTestMode?.name,
        'mode_history': card.modeHistory.map((mode) => mode.name).toList(),
        'cloze_text': card.clozeText,
        'accepted_answers': card.acceptedAnswers,
        'source': card.source,
        'difficulty': card.difficulty?.name,
        'level': card.level,
        'tags': card.tags,
        'due_at': card.dueAt.toIso8601String(),
        'last_reviewed_at': card.lastReviewedAt?.toIso8601String(),
        'interval_days': card.intervalDays,
        'ease_factor': card.easeFactor,
        'repetitions': card.repetitions,
        'lapses': card.lapses,
        'mastered': card.mastered,
        'created_at': card.createdAt.toIso8601String(),
        'updated_at': card.updatedAt.toIso8601String(),
      };

  Map<String, dynamic> reviewLogPayload(ReviewLog log) => {
        'id': log.id,
        'flashcard_id': log.flashcardId,
        'collection_id': log.collectionId,
        'deck_id': log.deckId,
        'review_result': log.reviewResult.name,
        'test_mode': log.testMode.name,
        'was_correct': log.wasCorrect,
        'created_at': log.createdAt.toIso8601String(),
        'scheduled_due_at': log.scheduledDueAt.toIso8601String(),
      };

  String _slugify(String input) {
    final cleaned = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return cleaned.isEmpty ? _uuid.v4() : cleaned;
  }
}
