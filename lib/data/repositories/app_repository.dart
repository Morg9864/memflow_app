import 'dart:async';
import 'dart:math' as math;

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/models.dart';
import '../../domain/services/card_mode_service.dart';
import '../../domain/services/spaced_repetition_service.dart';

class AppRepository {
  AppRepository({
    required SupabaseClient client,
    required SpacedRepetitionService spacedRepetitionService,
    required CardModeService cardModeService,
    void Function()? onDataChanged,
  }) : _client = client,
       _spacedRepetitionService = spacedRepetitionService,
       _cardModeService = cardModeService,
       _onDataChanged = onDataChanged;

  final SupabaseClient _client;
  final SpacedRepetitionService _spacedRepetitionService;
  final CardModeService _cardModeService;
  final void Function()? _onDataChanged;
  final Uuid _uuid = const Uuid();

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Une session Supabase active est requise.');
    }
    return userId;
  }

  void _notifyDataChanged() {
    _onDataChanged?.call();
  }

  Stream<List<CollectionListItem>> watchCollections({String search = ''}) {
    final lowered = search.trim().toLowerCase();
    return _combineLatest4(
      _watchCollectionsInternal(),
      _watchFlashcardsInternal(),
      _watchReviewLogsInternal(),
      _clockStream(),
      (collections, flashcards, reviewLogs, now) {
        final items =
            collections
                .map(
                  (collection) => _buildCollectionListItem(
                    collection,
                    flashcards
                        .where((card) => card.collectionId == collection.id)
                        .toList(),
                    reviewLogs
                        .where((log) => log.collectionId == collection.id)
                        .toList(),
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
    return _combineLatest3(
      _watchDecksInternal(collectionId: collectionId),
      _watchFlashcardsInternal(collectionId: collectionId),
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
    return _combineLatest3(
      _watchFlashcardsInternal(),
      _watchReviewLogsInternal(),
      _clockStream(),
      (flashcards, reviewLogs, now) => _buildHomeStats(
        flashcards: flashcards,
        reviewLogs: reviewLogs,
        now: now,
      ),
    );
  }

  Stream<StatisticsOverview> watchStatisticsOverview() {
    return _combineLatest3(
      _watchFlashcardsInternal(),
      _watchReviewLogsInternal(),
      _clockStream(),
      (flashcards, reviewLogs, now) => _buildStatisticsOverview(
        flashcards: flashcards,
        reviewLogs: reviewLogs,
        now: now,
      ),
    );
  }

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
      sessionCardIds: cards.map((card) => card.id).toSet(),
      seenCardIds: const <String>{},
      pendingReviewResults: const <String, ReviewResult>{},
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

  Future<void> submitReview({
    required String cardId,
    required ReviewResult reviewResult,
    required bool wasCorrect,
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
    final nextMode = _cardModeService.nextMode(card, reviewResult);

    await _client
        .from('flashcards')
        .update({
          'current_test_mode': nextMode.name,
          'last_test_mode': card.currentTestMode.name,
          'mode_history': _cardModeService
              .updatedModeHistory(card, nextMode)
              .map((mode) => mode.name)
              .toList(),
          'due_at': scheduleUpdate.dueAt.toUtc().toIso8601String(),
          'last_reviewed_at': scheduleUpdate.lastReviewedAt
              .toUtc()
              .toIso8601String(),
          'interval_days': scheduleUpdate.intervalDays,
          'ease_factor': scheduleUpdate.easeFactor,
          'repetitions': scheduleUpdate.repetitions,
          'lapses': scheduleUpdate.lapses,
          'mastered': scheduleUpdate.mastered,
          'updated_at': now.toUtc().toIso8601String(),
        })
        .eq('id', card.id)
        .eq('user_id', _userId);

    await _client.from('review_logs').insert({
      'id': _uuid.v4(),
      'flashcard_id': card.id,
      'collection_id': card.collectionId,
      'deck_id': card.deckId,
      'review_result': reviewResult.name,
      'test_mode': card.currentTestMode.name,
      'was_correct': wasCorrect,
      'created_at': now.toUtc().toIso8601String(),
      'scheduled_due_at': card.dueAt.toUtc().toIso8601String(),
    });

    _notifyDataChanged();
  }

  Future<void> importCards(CsvImportPreview preview) async {
    if (preview.cards.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
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
        await _client.from('collections').insert({
          'id': collection.id,
          'name': collection.name,
          'description': collection.description,
          'icon': collection.icon,
          'total_cards': 0,
          'mastered_percentage': 0,
          'color': collection.color,
          'created_at': collection.createdAt.toIso8601String(),
          'updated_at': collection.updatedAt.toIso8601String(),
        });
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
        await _client.from('decks').insert({
          'id': deck.id,
          'collection_id': deck.collectionId,
          'name': deck.name,
          'icon': deck.icon,
          'difficulty': deck.difficulty.name,
          'total_cards': 0,
          'due_cards': 0,
          'progress': 0,
          'status': DeckStatus.nouveau.name,
          'created_at': deck.createdAt.toIso8601String(),
          'updated_at': deck.updatedAt.toIso8601String(),
        });
        decksByKey[deckKey] = deck;
      }

      await _client.from('flashcards').insert({
        'id': _uuid.v4(),
        'collection_id': collection.id,
        'deck_id': deck.id,
        'question': draft.question,
        'correct_answer': draft.correctAnswer,
        'answer': draft.correctAnswer,
        'wrong_answers': draft.wrongAnswers,
        'hint': draft.hint,
        'explanation': draft.explanation,
        'current_test_mode': TestMode.multipleChoice.name,
        'allowed_test_modes': draft.allowedTestModes
            .map((mode) => mode.name)
            .toList(),
        'last_test_mode': null,
        'mode_history': [TestMode.multipleChoice.name],
        'cloze_text': draft.clozeText,
        'cloze_answers': draft.clozeAnswers,
        'cloze_word_bank': draft.clozeWordBank,
        'accepted_answers': draft.acceptedAnswers,
        'source': draft.source,
        'difficulty': draft.difficulty.name,
        'level': draft.level,
        'tags': draft.tags,
        'due_at': now.toIso8601String(),
        'last_reviewed_at': null,
        'interval_days': 0,
        'ease_factor': 2.5,
        'repetitions': 0,
        'lapses': 0,
        'mastered': false,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    }

    _notifyDataChanged();
  }

  Stream<List<FlashcardSummary>> watchFlashcardsForDeck(String deckId) {
    return _watchFlashcardsInternal(deckId: deckId).map((cards) {
      final sortedCards = [...cards]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return sortedCards
          .map(
            (card) => FlashcardSummary(
              id: card.id,
              deckId: card.deckId,
              collectionId: card.collectionId,
              question: card.question,
              correctAnswer: card.correctAnswer,
            ),
          )
          .toList();
    });
  }

  Stream<List<FlashcardDueItem>> watchDueCardsForCollection(
    String collectionId,
  ) {
    return _combineLatest3(
      _watchFlashcardsInternal(collectionId: collectionId),
      _watchDecksInternal(collectionId: collectionId),
      _clockStream(),
      (cards, decks, now) {
        final deckNames = {for (final deck in decks) deck.id: deck.name};
        final sortedCards = [...cards]
          ..sort((a, b) {
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

            return a.question.toLowerCase().compareTo(b.question.toLowerCase());
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

  Future<void> deleteFlashcard(String cardId) async {
    await _client
        .from('flashcards')
        .delete()
        .eq('id', cardId)
        .eq('user_id', _userId);
    _notifyDataChanged();
  }

  Future<void> updateFlashcardDueAt({
    required String cardId,
    required DateTime dueAt,
  }) async {
    await _client
        .from('flashcards')
        .update({
          'due_at': dueAt.toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', cardId)
        .eq('user_id', _userId);
    _notifyDataChanged();
  }

  Future<void> deleteDeck(String deckId) async {
    await _client
        .from('decks')
        .delete()
        .eq('id', deckId)
        .eq('user_id', _userId);
    _notifyDataChanged();
  }

  Future<void> deleteCollection(String collectionId) async {
    await _client
        .from('collections')
        .delete()
        .eq('id', collectionId)
        .eq('user_id', _userId);
    _notifyDataChanged();
  }

  Future<String> exportAllCardsCsv() async {
    final collections = await _fetchCollections();
    final decks = await _fetchDecks();
    final cards = await _fetchFlashcards();

    final collectionMap = {
      for (final collection in collections) collection.id: collection.name,
    };
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
        'cloze_answers',
        'cloze_word_bank',
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
        card.clozeAnswers.join('|'),
        card.clozeWordBank.join('|'),
      ]);
    }

    return Csv(fieldDelimiter: ';').encode(rows);
  }

  Future<CollectionRecord?> _fetchCollection(String id) async {
    final rows = await _selectRows(
      'collections',
      equals: {'id': id},
      orderBy: 'created_at',
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapCollection(rows.first);
  }

  Future<DeckRecord?> _fetchDeck(String id) async {
    final rows = await _selectRows(
      'decks',
      equals: {'id': id},
      orderBy: 'created_at',
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapDeck(rows.first);
  }

  Future<FlashcardRecord?> _fetchFlashcard(String id) async {
    final rows = await _selectRows(
      'flashcards',
      equals: {'id': id},
      orderBy: 'created_at',
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapFlashcard(rows.first);
  }

  Future<List<CollectionRecord>> _fetchCollections() async {
    final rows = await _selectRows('collections', orderBy: 'name');
    return rows.map(_mapCollection).toList();
  }

  Future<List<DeckRecord>> _fetchDecks({String? collectionId}) async {
    final equals = <String, Object?>{};
    if (collectionId != null) {
      equals['collection_id'] = collectionId;
    }
    final rows = await _selectRows(
      'decks',
      equals: equals,
      orderBy: 'created_at',
    );
    return rows.map(_mapDeck).toList();
  }

  Future<List<FlashcardRecord>> _fetchFlashcards({
    String? collectionId,
    String? deckId,
    DateTime? dueBeforeOrAt,
    int? limit,
  }) async {
    final equals = <String, Object?>{};
    if (collectionId != null) {
      equals['collection_id'] = collectionId;
    }
    if (deckId != null) {
      equals['deck_id'] = deckId;
    }
    final rows = await _selectRows(
      'flashcards',
      equals: equals,
      dueBeforeOrAt: dueBeforeOrAt,
      orderBy: 'due_at',
      limit: limit,
    );
    return rows.map(_mapFlashcard).toList();
  }

  Stream<List<CollectionRecord>> _watchCollectionsInternal() {
    return _streamRows(
      'collections',
      orderBy: 'name',
    ).map((rows) => rows.map(_mapCollection).toList());
  }

  Stream<List<DeckRecord>> _watchDecksInternal({String? collectionId}) {
    final equals = <String, Object?>{};
    if (collectionId != null) {
      equals['collection_id'] = collectionId;
    }
    return _streamRows(
      'decks',
      equals: equals,
      orderBy: 'created_at',
    ).map((rows) => rows.map(_mapDeck).toList());
  }

  Stream<List<FlashcardRecord>> _watchFlashcardsInternal({
    String? collectionId,
    String? deckId,
  }) {
    final equals = <String, Object?>{};
    if (collectionId != null) {
      equals['collection_id'] = collectionId;
    }
    if (deckId != null) {
      equals['deck_id'] = deckId;
    }
    return _streamRows(
      'flashcards',
      equals: equals,
      orderBy: 'due_at',
    ).map((rows) => rows.map(_mapFlashcard).toList());
  }

  Stream<List<ReviewLogRecord>> _watchReviewLogsInternal() {
    return _streamRows(
      'review_logs',
      orderBy: 'created_at',
    ).map((rows) => rows.map(_mapReviewLog).toList());
  }

  Future<List<FlashcardRecord>> _loadSessionCards({
    required String? collectionId,
    required String? deckId,
    required DateTime now,
    required int sessionCardLimit,
  }) async {
    final dueCards = await _fetchFlashcards(
      collectionId: collectionId,
      deckId: deckId,
      dueBeforeOrAt: now,
    );
    if (dueCards.isNotEmpty) {
      return _takeSessionCards(dueCards, sessionCardLimit);
    }

    final cards = await _fetchFlashcards(
      collectionId: collectionId,
      deckId: deckId,
    );
    return _takeSessionCards(cards, sessionCardLimit);
  }

  List<FlashcardRecord> _takeSessionCards(
    Iterable<FlashcardRecord> cards,
    int sessionCardLimit,
  ) {
    final sortedCards = [...cards]
      ..sort((a, b) {
        final byCreatedAt = a.createdAt.compareTo(b.createdAt);
        if (byCreatedAt != 0) {
          return byCreatedAt;
        }
        return a.id.compareTo(b.id);
      });

    if (sortedCards.isEmpty) {
      return const [];
    }

    final effectiveLimit = sessionCardLimit.clamp(1, sortedCards.length);
    return sortedCards.take(effectiveLimit).toList();
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

  TestMode _resolveMode(FlashcardRecord card, TestMode? forcedMode) {
    final resolved = _selectMode(card, forcedMode);
    // Le mode vrai/faux a besoin d'au moins une mauvaise réponse pour pouvoir
    // afficher une proposition incorrecte. Sans cela, on bascule sur la
    // flashcard classique plutôt que de présenter un mode dégradé.
    final hasWrongAnswer = card.wrongAnswers.any(
      (answer) => answer.trim().isNotEmpty,
    );
    if (resolved == TestMode.trueFalse && !hasWrongAnswer) {
      return TestMode.classicFlashcard;
    }
    return resolved;
  }

  TestMode _selectMode(FlashcardRecord card, TestMode? forcedMode) {
    if (forcedMode == null) {
      final allowed = card.allowedTestModes
          .where(
            (mode) => mode != TestMode.ordering && mode != TestMode.matching,
          )
          .toList();
      if (allowed.isEmpty) {
        return TestMode.classicFlashcard;
      }
      return allowed[math.Random().nextInt(allowed.length)];
    }
    if (forcedMode == TestMode.ordering || forcedMode == TestMode.matching) {
      return TestMode.classicFlashcard;
    }
    if (card.allowedTestModes.contains(forcedMode)) {
      return forcedMode;
    }
    if (forcedMode == TestMode.cloze &&
        card.allowedTestModes.contains(TestMode.freeText)) {
      return TestMode.freeText;
    }
    if (card.allowedTestModes.contains(TestMode.classicFlashcard)) {
      return TestMode.classicFlashcard;
    }
    if (card.allowedTestModes.isNotEmpty) {
      return card.allowedTestModes.first;
    }
    return TestMode.classicFlashcard;
  }

  CollectionListItem _buildCollectionListItem(
    CollectionRecord collection,
    List<FlashcardRecord> flashcards,
    List<ReviewLogRecord> reviewLogs,
    DateTime now,
  ) {
    final cardsDone = flashcards.where((card) => card.repetitions > 0).length;
    final dueCards = flashcards
        .where((card) => !_isDueInFuture(card.dueAt, now))
        .length;
    final errorCount = reviewLogs.where((log) => !log.wasCorrect).length;

    return CollectionListItem(
      id: collection.id,
      name: collection.name,
      description: collection.description,
      icon: collection.icon,
      totalCards: flashcards.length,
      cardsDone: cardsDone,
      dueCards: dueCards,
      color: collection.color,
      createdAt: collection.createdAt,
      updatedAt: collection.updatedAt,
      errorCount: errorCount,
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
    );
  }

  HomeStats _buildHomeStats({
    required List<FlashcardRecord> flashcards,
    required List<ReviewLogRecord> reviewLogs,
    required DateTime now,
  }) {
    final dueCards = flashcards
        .where((card) => !_isDueInFuture(card.dueAt, now))
        .length;
    final successCount = reviewLogs.where((log) => log.wasCorrect).length;
    final successRate = reviewLogs.isEmpty
        ? 0.0
        : successCount / reviewLogs.length;

    return HomeStats(
      streakDays: _calculateStreak(
        reviewLogs.map((log) => log.createdAt).toList(),
        now: now,
      ),
      successRate: successRate,
      dueCards: dueCards,
      totalCardsSeen: reviewLogs.length,
    );
  }

  StatisticsOverview _buildStatisticsOverview({
    required List<FlashcardRecord> flashcards,
    required List<ReviewLogRecord> reviewLogs,
    required DateTime now,
  }) {
    final successCount = reviewLogs.where((log) => log.wasCorrect).length;
    final successRate = reviewLogs.isEmpty
        ? 0.0
        : successCount / reviewLogs.length;
    final studyDayMap = <DateTime, int>{};

    for (final review in reviewLogs) {
      final localDate = review.createdAt.toLocal();
      final key = DateTime(localDate.year, localDate.month, localDate.day);
      studyDayMap.update(key, (value) => value + 1, ifAbsent: () => 1);
    }

    final localNow = now.toLocal();
    final heatmap = List.generate(4, (weekIndex) {
      return List.generate(7, (dayIndex) {
        final date = DateTime(
          localNow.year,
          localNow.month,
          localNow.day,
        ).subtract(Duration(days: (3 - weekIndex) * 7 + (6 - dayIndex)));
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
    final maxLevel = levelCounts.values.fold<int>(1, math.max);

    return StatisticsOverview(
      streakDays: _calculateStreak(
        reviewLogs.map((log) => log.createdAt).toList(),
        now: now,
      ),
      totalReviews: reviewLogs.length,
      successRate: successRate,
      studyDays: studyDayMap.length,
      heatmap: heatmap,
      levelProgress: [
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
      ],
    );
  }

  int _calculateStreak(List<DateTime> timestamps, {required DateTime now}) {
    final daySet = timestamps
        .map((date) => date.toLocal())
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();
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

  bool _isDueInFuture(DateTime dueAt, DateTime now) {
    return dueAt.isAfter(now);
  }

  Future<List<Map<String, dynamic>>> _selectRows(
    String table, {
    Map<String, Object?> equals = const {},
    DateTime? dueBeforeOrAt,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    dynamic builder = _client.from(table).select();
    builder = builder.eq('user_id', _userId);
    for (final entry in equals.entries) {
      builder = builder.eq(entry.key, entry.value);
    }
    if (dueBeforeOrAt != null) {
      builder = builder.lte('due_at', dueBeforeOrAt.toUtc().toIso8601String());
    }
    if (orderBy != null) {
      builder = builder.order(orderBy, ascending: ascending);
    }
    if (limit != null) {
      builder = builder.limit(limit);
    }
    final rows = await builder;
    return List<Map<String, dynamic>>.from(
      (rows as List).map((row) => Map<String, dynamic>.from(row as Map)),
    );
  }

  Stream<List<Map<String, dynamic>>> _streamRows(
    String table, {
    Map<String, Object?> equals = const {},
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) {
    dynamic builder = _client.from(table).stream(primaryKey: ['id']);
    builder = builder.eq('user_id', _userId);
    for (final entry in equals.entries) {
      builder = builder.eq(entry.key, entry.value);
    }
    if (orderBy != null) {
      builder = builder.order(orderBy, ascending: ascending);
    }
    if (limit != null) {
      builder = builder.limit(limit);
    }

    return (builder as Stream<List<dynamic>>).map(
      (rows) => rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false),
    );
  }

  CollectionRecord _mapCollection(Map<String, dynamic> row) {
    return CollectionRecord(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String,
      icon: row['icon'] as String,
      color: (row['color'] as num).toInt(),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  DeckRecord _mapDeck(Map<String, dynamic> row) {
    return DeckRecord(
      id: row['id'] as String,
      collectionId: row['collection_id'] as String,
      name: row['name'] as String,
      icon: row['icon'] as String,
      difficulty: DeckDifficulty.values.firstWhere(
        (value) => value.name == row['difficulty'],
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  FlashcardRecord _mapFlashcard(Map<String, dynamic> row) {
    return FlashcardRecord(
      id: row['id'] as String,
      collectionId: row['collection_id'] as String,
      deckId: row['deck_id'] as String,
      question: row['question'] as String,
      correctAnswer: row['correct_answer'] as String,
      answer: row['answer'] as String?,
      wrongAnswers: _toStringList(row['wrong_answers']),
      hint: row['hint'] as String?,
      explanation: row['explanation'] as String?,
      currentTestMode: TestMode.values.firstWhere(
        (value) => value.name == row['current_test_mode'],
      ),
      allowedTestModes: _toStringList(row['allowed_test_modes'])
          .map(
            (item) => TestMode.values.firstWhere((mode) => mode.name == item),
          )
          .toList(),
      lastTestMode: row['last_test_mode'] == null
          ? null
          : TestMode.values.firstWhere(
              (value) => value.name == row['last_test_mode'],
            ),
      modeHistory: _toStringList(row['mode_history'])
          .map(
            (item) => TestMode.values.firstWhere((mode) => mode.name == item),
          )
          .toList(),
      clozeText: row['cloze_text'] as String?,
      clozeAnswers: _toStringList(row['cloze_answers']),
      clozeWordBank: _toStringList(row['cloze_word_bank']),
      acceptedAnswers: _toStringList(row['accepted_answers']),
      source: row['source'] as String?,
      difficulty: row['difficulty'] == null
          ? null
          : DeckDifficulty.values.firstWhere(
              (value) => value.name == row['difficulty'],
            ),
      level: (row['level'] as num).toInt(),
      tags: _toStringList(row['tags']),
      dueAt: DateTime.parse(row['due_at'] as String),
      lastReviewedAt: row['last_reviewed_at'] == null
          ? null
          : DateTime.parse(row['last_reviewed_at'] as String),
      intervalDays: (row['interval_days'] as num).toDouble(),
      easeFactor: (row['ease_factor'] as num).toDouble(),
      repetitions: (row['repetitions'] as num).toInt(),
      lapses: (row['lapses'] as num).toInt(),
      mastered: row['mastered'] as bool,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  ReviewLogRecord _mapReviewLog(Map<String, dynamic> row) {
    return ReviewLogRecord(
      id: row['id'] as String,
      flashcardId: row['flashcard_id'] as String,
      collectionId: row['collection_id'] as String,
      deckId: row['deck_id'] as String,
      reviewResult: ReviewResult.values.firstWhere(
        (value) => value.name == row['review_result'],
      ),
      testMode: TestMode.values.firstWhere(
        (value) => value.name == row['test_mode'],
      ),
      wasCorrect: row['was_correct'] as bool,
      createdAt: DateTime.parse(row['created_at'] as String),
      scheduledDueAt: DateTime.parse(row['scheduled_due_at'] as String),
    );
  }

  List<String> _toStringList(dynamic value) {
    if (value == null) {
      return const [];
    }
    return List<String>.from((value as List).map((item) => item.toString()));
  }

  T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) predicate) {
    for (final item in items) {
      if (predicate(item)) {
        return item;
      }
    }
    return null;
  }

  Stream<DateTime> _clockStream({
    Duration interval = const Duration(minutes: 1),
  }) async* {
    yield DateTime.now();
    yield* Stream.periodic(interval, (_) => DateTime.now());
  }
}

Stream<R> _combineLatest3<A, B, C, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  Stream<C> streamC,
  R Function(A a, B b, C c) combine,
) {
  late final StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  StreamSubscription<C>? subC;
  A? latestA;
  B? latestB;
  C? latestC;
  var hasA = false;
  var hasB = false;
  var hasC = false;

  void emit() {
    if (hasA && hasB && hasC) {
      controller.add(combine(latestA as A, latestB as B, latestC as C));
    }
  }

  controller = StreamController<R>(
    onListen: () {
      subA = streamA.listen((value) {
        latestA = value;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = streamB.listen((value) {
        latestB = value;
        hasB = true;
        emit();
      }, onError: controller.addError);
      subC = streamC.listen((value) {
        latestC = value;
        hasC = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
      await subC?.cancel();
    },
  );

  return controller.stream;
}

Stream<R> _combineLatest4<A, B, C, D, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  Stream<C> streamC,
  Stream<D> streamD,
  R Function(A a, B b, C c, D d) combine,
) {
  late final StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  StreamSubscription<C>? subC;
  StreamSubscription<D>? subD;
  A? latestA;
  B? latestB;
  C? latestC;
  D? latestD;
  var hasA = false;
  var hasB = false;
  var hasC = false;
  var hasD = false;

  void emit() {
    if (hasA && hasB && hasC && hasD) {
      controller.add(
        combine(latestA as A, latestB as B, latestC as C, latestD as D),
      );
    }
  }

  controller = StreamController<R>(
    onListen: () {
      subA = streamA.listen((value) {
        latestA = value;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = streamB.listen((value) {
        latestB = value;
        hasB = true;
        emit();
      }, onError: controller.addError);
      subC = streamC.listen((value) {
        latestC = value;
        hasC = true;
        emit();
      }, onError: controller.addError);
      subD = streamD.listen((value) {
        latestD = value;
        hasD = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
      await subC?.cancel();
      await subD?.cancel();
    },
  );

  return controller.stream;
}
