import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/data/local/database.dart';
import 'package:memflow/data/repositories/app_repository.dart';
import 'package:memflow/data/sync/sync_service.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/card_mode_service.dart';
import 'package:memflow/domain/services/spaced_repetition_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ces tests tournent sans le moindre accès réseau : le client Supabase n'a
/// aucune session, donc la synchronisation devient un no-op. C'est exactement
/// la situation d'un utilisateur hors ligne, et tout doit continuer à marcher.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late AppRepository repository;

  setUp(() {
    database = AppDatabase.memory();
    repository = AppRepository(
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
  });

  tearDown(() => database.close());

  CsvImportCardDraft draft({
    String collection = 'Systèmes',
    String deck = 'Chapitre 1',
    String question = 'Question ?',
    String correctAnswer = 'Bonne',
    List<String> wrongAnswers = const [
      'Mauvaise 1',
      'Mauvaise 2',
      'Mauvaise 3',
    ],
    List<String> acceptedAnswers = const [],
    int level = 1,
  }) {
    return CsvImportCardDraft(
      collection: collection,
      deck: deck,
      question: question,
      correctAnswer: correctAnswer,
      wrongAnswers: wrongAnswers,
      hint: null,
      explanation: null,
      level: level,
      tags: const [],
      source: null,
      clozeText: null,
      clozeAnswers: const [],
      clozeWordBank: const [],
      acceptedAnswers: acceptedAnswers,
      allowedTestModes: const CardModeService().allowedModesFor(
        clozeText: null,
        acceptedAnswers: acceptedAnswers,
        wrongAnswers: wrongAnswers,
      ),
    );
  }

  Future<void> importDrafts(List<CsvImportCardDraft> cards) {
    return repository.importCards(
      CsvImportPreview(
        cards: cards,
        issues: const [],
        delimiter: ';',
        withHeader: true,
      ),
    );
  }

  test('un import hors ligne écrit en local et met tout en file', () async {
    await importDrafts([draft(), draft(question: 'Deuxième ?')]);

    final collections = await database.select(database.collections).get();
    final decks = await database.select(database.decks).get();
    final cards = await database.select(database.flashcards).get();
    expect(collections, hasLength(1));
    expect(decks, hasLength(1));
    expect(cards, hasLength(2));

    // Une collection + un deck + deux cartes.
    final pending = await database.pendingSyncEntries();
    expect(pending, hasLength(4));
    expect(
      pending.every((entry) => entry.operation == SyncOperation.upsert),
      isTrue,
    );
  });

  test('une session démarre entièrement depuis la base locale', () async {
    await importDrafts([
      draft(question: 'Q1'),
      draft(question: 'Q2'),
      draft(question: 'Q3'),
    ]);

    final session = await repository.startStudySession(sessionCardLimit: 2);

    expect(session.cards, hasLength(2));
    expect(session.deckTitle, 'Révision');
  });

  for (final scope in ['global', 'collection', 'deck']) {
    test(
      'les cartes dues passent avant les futures en session $scope',
      () async {
        await importDrafts([
          for (var i = 0; i < 30; i++) draft(question: 'Q$i'),
        ]);
        final now = DateTime.now();
        final imported = await database.select(database.flashcards).get();
        final byQuestion = {for (final card in imported) card.question: card};
        for (var i = 0; i < 30; i++) {
          final card = byQuestion['Q$i']!;
          await (database.update(
            database.flashcards,
          )..where((row) => row.id.equals(card.id))).write(
            FlashcardsCompanion(
              createdAt: Value(now.subtract(Duration(minutes: 30 - i))),
              dueAt: Value(
                i < 12
                    ? now.add(Duration(days: [1, 3, 8][i % 3]))
                    : now.subtract(const Duration(minutes: 1)),
              ),
              repetitions: Value(i < 12 ? 1 : 0),
            ),
          );
        }

        Future<StudySessionState> start() => repository.startStudySession(
          collectionId: scope == 'global' ? null : imported.first.collectionId,
          deckId: scope == 'deck' ? imported.first.deckId : null,
          forcedMode: scope == 'deck' ? TestMode.multipleChoice : null,
          sessionCardLimit: 12,
        );

        final first = await start();
        expect(
          first.cards.map((card) => card.question),
          [for (var i = 12; i < 24; i++) 'Q$i'],
          reason: 'Les 12 anciennes cartes futures ne doivent pas masquer now.',
        );
        for (final card in first.cards) {
          await repository.submitReview(
            cardId: card.id,
            reviewResult: ReviewResult.good,
            wasCorrect: true,
            playedMode: card.currentTestMode,
          );
        }
        await repository.saveStudySession(first.copyWith(isCompleted: true));

        final next = await start();
        expect(next.cards.take(6).map((card) => card.question), [
          'Q24',
          'Q25',
          'Q26',
          'Q27',
          'Q28',
          'Q29',
        ], reason: 'Les 6 cartes encore dues ouvrent la session suivante.');
        expect(next.cards, hasLength(12));
        expect(next.cards.map((card) => card.id).toSet(), hasLength(12));
      },
    );
  }

  test('la difficulté du deck est inférée par moyenne des niveaux', () async {
    await importDrafts([
      draft(question: 'Q1', level: 1),
      draft(question: 'Q2', level: 4),
    ]);

    final deck = (await database.select(database.decks).get()).single;
    expect(deck.difficulty, DeckDifficulty.difficile);
  });

  test('une révision avance la carte et journalise le mode joué', () async {
    await importDrafts([draft()]);
    final card = (await database.select(database.flashcards).get()).single;

    await repository.submitReview(
      cardId: card.id,
      reviewResult: ReviewResult.good,
      wasCorrect: true,
      playedMode: TestMode.trueFalse,
    );

    final log = (await database.select(database.reviewLogs).get()).single;
    expect(log.testMode, TestMode.trueFalse, reason: 'le mode réellement joué');
    expect(log.wasCorrect, isTrue);

    final updated = (await database.select(database.flashcards).get()).single;
    expect(updated.repetitions, 1);
    expect(updated.lastTestMode, TestMode.trueFalse);
    expect(updated.modeHistory, contains(TestMode.trueFalse));
  });

  test('le mode stocké pilote la carte suivante en mode adaptatif', () async {
    await importDrafts([draft()]);
    final card = (await database.select(database.flashcards).get()).single;

    // Un succès en QCM promeut la carte vers la flashcard classique.
    await repository.submitReview(
      cardId: card.id,
      reviewResult: ReviewResult.good,
      wasCorrect: true,
      playedMode: TestMode.multipleChoice,
    );

    final session = await repository.startStudySession(sessionCardLimit: 1);
    expect(session.currentCard.currentTestMode, TestMode.classicFlashcard);
  });

  test('un mode imposé est respecté quand la carte le supporte', () async {
    await importDrafts([draft()]);

    final session = await repository.startStudySession(
      sessionCardLimit: 1,
      forcedMode: TestMode.trueFalse,
    );

    expect(session.currentCard.currentTestMode, TestMode.trueFalse);
  });

  test('un mode imposé indisponible est refusé explicitement', () async {
    await importDrafts([draft()]);

    expect(
      () => repository.startStudySession(
        sessionCardLimit: 1,
        forcedMode: TestMode.cloze,
      ),
      throwsStateError,
    );
  });

  test('réécrire la même carte ne produit qu\'une intention', () async {
    await importDrafts([draft()]);
    final card = (await database.select(database.flashcards).get()).single;
    await database.delete(database.syncQueueEntries).go();

    for (var i = 0; i < 3; i++) {
      await repository.updateFlashcardDueAt(
        cardId: card.id,
        dueAt: DateTime(2026, 9, i + 1),
      );
    }

    final pending = await database.pendingSyncEntries();
    expect(pending, hasLength(1));
    expect(pending.single.entityId, card.id);
  });

  test('supprimer un deck purge ses cartes et ses journaux en local', () async {
    await importDrafts([draft(), draft(question: 'Autre ?')]);
    final card = (await database.select(database.flashcards).get()).first;
    await repository.submitReview(
      cardId: card.id,
      reviewResult: ReviewResult.again,
      wasCorrect: false,
      playedMode: TestMode.multipleChoice,
    );
    final deck = (await database.select(database.decks).get()).single;
    await database.delete(database.syncQueueEntries).go();

    await repository.deleteDeck(deck.id);

    expect(await database.select(database.flashcards).get(), isEmpty);
    expect(await database.select(database.reviewLogs).get(), isEmpty);

    // La cascade est gérée côté serveur : un seul ordre part sur le réseau.
    final pending = await database.pendingSyncEntries();
    expect(pending, hasLength(1));
    expect(pending.single.entityType, SyncEntityType.deck);
    expect(pending.single.operation, SyncOperation.delete);
  });

  test('les statistiques se calculent sur les données locales', () async {
    await importDrafts([draft(), draft(question: 'Autre ?')]);
    final cards = await database.select(database.flashcards).get();
    await repository.submitReview(
      cardId: cards.first.id,
      reviewResult: ReviewResult.good,
      wasCorrect: true,
      playedMode: TestMode.multipleChoice,
    );
    await repository.submitReview(
      cardId: cards.last.id,
      reviewResult: ReviewResult.again,
      wasCorrect: false,
      playedMode: TestMode.multipleChoice,
    );

    final stats = await repository.watchStatisticsOverview().first;

    expect(stats.totalReviews, 2);
    expect(stats.successRate, 0.5);
    expect(stats.studyDays, 1);
    expect(stats.streakDays, 1);
    expect(stats.heatmap.last.count, 2);
    expect(stats.successTrend.last.reviewCount, 2);
    expect(stats.successTrend.last.successRate, 0.5);
    expect(stats.collectionProgress.single.name, 'Systèmes');
    expect(stats.collectionProgress.single.successRate, 0.5);
    expect(stats.modeProgress.single.mode, TestMode.multipleChoice);
    expect(stats.modeProgress.single.successRate, 0.5);
    expect(stats.difficultCards.single.errorCount, 1);
  });

  test('le compteur d\'erreurs remonte par collection', () async {
    await importDrafts([draft()]);
    final card = (await database.select(database.flashcards).get()).single;
    await repository.submitReview(
      cardId: card.id,
      reviewResult: ReviewResult.again,
      wasCorrect: false,
      playedMode: TestMode.multipleChoice,
    );

    final collections = await repository.watchCollections().first;

    expect(collections.single.errorCount, 1);
    expect(collections.single.totalCards, 1);
  });

  test('une session interrompue est restaurée depuis la base locale', () async {
    await importDrafts([draft(), draft(question: 'Deuxième ?')]);
    final created = await repository.startStudySession(sessionCardLimit: 2);
    await repository.saveStudySession(created.copyWith(currentIndex: 1));

    final restored = await repository.startStudySession(sessionCardLimit: 2);

    expect(restored.sessionId, created.sessionId);
    expect(restored.currentIndex, 1);
    expect(restored.cards.map((card) => card.id), created.cards.map((card) => card.id));
  });

  test('une review avec le même identifiant est idempotente', () async {
    await importDrafts([draft()]);
    final card = (await database.select(database.flashcards).get()).single;

    await repository.submitReview(
      reviewId: 'review-1',
      cardId: card.id,
      reviewResult: ReviewResult.good,
      wasCorrect: true,
      playedMode: TestMode.multipleChoice,
    );
    await repository.submitReview(
      reviewId: 'review-1',
      cardId: card.id,
      reviewResult: ReviewResult.good,
      wasCorrect: true,
      playedMode: TestMode.multipleChoice,
    );

    final updated = (await database.select(database.flashcards).get()).single;
    expect(updated.repetitions, 1);
    expect(await database.select(database.reviewLogs).get(), hasLength(1));
  });
}
