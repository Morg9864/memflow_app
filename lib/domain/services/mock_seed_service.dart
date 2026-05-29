import 'package:drift/drift.dart';

import '../../data/local/database.dart';
import '../models/models.dart';
import 'card_mode_service.dart';

class MockSeedService {
  MockSeedService({
    required AppDatabase database,
    required CardModeService cardModeService,
  })  : _database = database,
        _cardModeService = cardModeService;

  final AppDatabase _database;
  final CardModeService _cardModeService;

  Future<void> seedIfNeeded() async {
    if (!await _database.isEmpty()) {
      return;
    }

    await _database.transaction(() async {
      final now = DateTime.now();
      final collections = [
        _collection('react', 'React & Hooks', 'Maîtriser l’écosystème React moderne.',
            '⚛️', const ColorToken(0xFFF08D49), now),
        _collection('python', 'Python', 'Syntaxe, structures et scripts.', '🐍',
            const ColorToken(0xFF7A9E7E), now),
        _collection('algo', 'Algorithmes', 'Pensée algorithmique et complexité.',
            '🧠', const ColorToken(0xFF5D86C7), now),
        _collection(
            'sql', 'SQL & BDD', 'Requêtes, jointures et modélisation.', '🗃️', const ColorToken(0xFFB68A58), now),
        _collection('http', 'HTTP & Réseaux', 'Protocoles, cache et sécurité.',
            '🌐', const ColorToken(0xFFB56A75), now),
      ];

      await _database.batch((batch) {
        batch.insertAll(_database.collections, collections);
      });

      final reactDecks = [
        _deck('react-hooks-base', 'react', 'Hooks de base', '🪝', DeckDifficulty.facile, now),
        _deck('react-state', 'react', 'Gestion d’état', '🧩', DeckDifficulty.moyen, now),
        _deck('react-lifecycle', 'react', 'Cycle de vie', '⏱️', DeckDifficulty.moyen, now),
        _deck('react-context', 'react', 'Context API', '🌿', DeckDifficulty.avance, now),
        _deck('react-performance', 'react', 'Performance & memo', '⚡', DeckDifficulty.avance, now),
        _deck('react-router', 'react', 'Routing avec React Router', '🧭', DeckDifficulty.moyen, now),
      ];

      final otherDecks = [
        _deck('python-basics', 'python', 'Python essentiel', '📘', DeckDifficulty.facile, now),
        _deck('algo-complexity', 'algo', 'Complexité', '📈', DeckDifficulty.moyen, now),
        _deck('sql-joins', 'sql', 'Jointures SQL', '🔗', DeckDifficulty.moyen, now),
        _deck('http-cache', 'http', 'Caching HTTP', '🛰️', DeckDifficulty.moyen, now),
      ];

      await _database.batch((batch) {
        batch.insertAll(_database.decks, [...reactDecks, ...otherDecks]);
      });

      final flashcards = <FlashcardsCompanion>[
        ..._buildReactCards(now),
        ..._buildSupplementalCards(now),
      ];

      await _database.batch((batch) {
        batch.insertAll(_database.flashcards, flashcards);
      });

      await _database.batch((batch) {
        batch.insertAll(_database.reviewLogs, _buildReviewLogs(now));
      });
    });
  }

  CollectionsCompanion _collection(
    String id,
    String name,
    String description,
    String icon,
    ColorToken color,
    DateTime now,
  ) {
    return CollectionsCompanion.insert(
      id: id,
      name: name,
      description: description,
      icon: icon,
      totalCards: 0,
      masteredPercentage: 0,
      color: color.value,
      createdAt: now,
      updatedAt: now,
    );
  }

  DecksCompanion _deck(
    String id,
    String collectionId,
    String name,
    String icon,
    DeckDifficulty difficulty,
    DateTime now,
  ) {
    return DecksCompanion.insert(
      id: id,
      collectionId: collectionId,
      name: name,
      icon: icon,
      difficulty: difficulty,
      totalCards: 0,
      dueCards: 0,
      progress: 0,
      status: DeckStatus.nouveau,
      createdAt: now,
      updatedAt: now,
    );
  }

  List<FlashcardsCompanion> _buildReactCards(DateTime now) {
    const prompts = [
      (
        'Quel hook React permet d’exécuter un effet de bord après le rendu ?',
        'useEffect, il s’exécute après que le DOM soit mis à jour. Le tableau de dépendances contrôle quand l’effet se relance.',
        ['useState', 'useMemo', 'useCallback'],
        'Un tableau vide [] fait que l’effet ne s’exécute qu’une seule fois, au montage.',
        'React utilise {{useEffect}} pour déclencher un effet de bord après un rendu.',
        ['useEffect', 'use effect'],
        'react-hooks-base',
      ),
      (
        'Quel hook permet de stocker un état local dans un composant ?',
        'useState permet de déclarer une valeur d’état et une fonction pour la modifier.',
        ['useEffect', 'useRef', 'useReducer'],
        'Il retourne une valeur et une fonction de mise à jour.',
        'Le hook {{useState}} permet de stocker un état local.',
        ['useState', 'use state'],
        'react-hooks-base',
      ),
      (
        'À quoi sert useMemo ?',
        'useMemo mémorise le résultat d’un calcul pour éviter de le recalculer inutilement.',
        ['useEffect', 'useLayoutEffect', 'useImperativeHandle'],
        'Pense optimisation de calcul.',
        'On utilise {{useMemo}} pour mémoriser le résultat d’un calcul.',
        ['useMemo', 'use memo'],
        'react-performance',
      ),
      (
        'À quoi sert useCallback ?',
        'useCallback mémorise une fonction entre deux rendus pour éviter des re-renders inutiles.',
        ['useContext', 'useSyncExternalStore', 'useId'],
        'La réponse concerne une fonction, pas une valeur.',
        'React garde une référence stable grâce à {{useCallback}}.',
        ['useCallback', 'use callback'],
        'react-performance',
      ),
      (
        'Pourquoi ne faut-il pas appeler un hook dans une condition ?',
        'React doit appeler les hooks dans le même ordre à chaque rendu pour associer correctement leur état interne.',
        ['Parce que la syntaxe JSX l’interdit', 'Parce que le hook devient global', 'Parce qu’il force un re-render'],
        'L’ordre d’appel est critique.',
        null,
        ['ordre des hooks', 'même ordre'],
        'react-hooks-base',
      ),
      (
        'Quel hook permet de lire la valeur d’un contexte React ?',
        'useContext lit la valeur courante d’un contexte fourni plus haut dans l’arbre.',
        ['useReducer', 'useMemo', 'useRef'],
        'Il consomme une valeur fournie par un Provider.',
        null,
        ['useContext', 'use context'],
        'react-context',
      ),
      (
        'Quel composant React Router affiche le contenu de la route enfant active ?',
        'Outlet rend la route enfant actuellement active dans la hiérarchie.',
        ['Route', 'Navigate', 'Switch'],
        'Pense à un emplacement réservé.',
        null,
        ['Outlet'],
        'react-router',
      ),
      (
        'Quel hook React Router permet de naviguer par code ?',
        'useNavigate retourne une fonction pour changer de route de manière impérative.',
        ['useLocation', 'useRouteError', 'useOutlet'],
        'Il renvoie une fonction.',
        null,
        ['useNavigate', 'use navigate'],
        'react-router',
      ),
    ];

    final cards = <FlashcardsCompanion>[];
    for (var i = 0; i < 24; i++) {
      final prompt = prompts[i % prompts.length];
      final reviewOffset = i % 6;
      final repetitions = switch (reviewOffset) { 0 => 0, 1 => 1, 2 => 2, 3 => 3, 4 => 4, _ => 2 };
      final mastered = repetitions >= 3;
      final dueAt = reviewOffset == 0 || reviewOffset == 2
          ? now.subtract(Duration(hours: reviewOffset + 1))
          : now.add(Duration(days: reviewOffset + 1));
      final acceptedAnswers = List<String>.from(prompt.$6);
      final clozeText = prompt.$5;
      cards.add(
        _flashcard(
          id: 'react-card-$i',
          collectionId: 'react',
          deckId: prompt.$7,
          question: prompt.$1,
          correctAnswer: prompt.$2,
          wrongAnswers: List<String>.from(prompt.$3),
          hint: prompt.$4,
          explanation: prompt.$2,
          currentTestMode: TestMode.multipleChoice,
          clozeText: clozeText,
          acceptedAnswers: acceptedAnswers,
          source: 'Cours React',
          level: (i % 4) + 1,
          tags: const ['react', 'hooks'],
          dueAt: dueAt,
          lastReviewedAt: repetitions > 0 ? now.subtract(Duration(days: repetitions)) : null,
          intervalDays: repetitions == 0 ? 0 : repetitions.toDouble(),
          easeFactor: 2.3 + ((i % 3) * 0.15),
          repetitions: repetitions,
          lapses: i % 5 == 0 ? 1 : 0,
          mastered: mastered,
          difficulty: DeckDifficulty.values[i % DeckDifficulty.values.length],
          createdAt: now.subtract(const Duration(days: 30)),
          updatedAt: now.subtract(Duration(days: i % 7)),
        ),
      );
    }
    return cards;
  }

  List<FlashcardsCompanion> _buildSupplementalCards(DateTime now) {
    return [
      _flashcard(
        id: 'python-card-1',
        collectionId: 'python',
        deckId: 'python-basics',
        question: 'Quel type Python représente une liste ordonnée et mutable ?',
        correctAnswer: 'list',
        wrongAnswers: const ['tuple', 'set', 'dict'],
        hint: 'Crochets []',
        explanation: 'Une list Python est ordonnée et mutable.',
        currentTestMode: TestMode.multipleChoice,
        clozeText: 'En Python, {{list}} représente une séquence mutable.',
        acceptedAnswers: const ['list'],
        source: 'Python handbook',
        level: 1,
        tags: const ['python'],
        dueAt: now.subtract(const Duration(hours: 2)),
        lastReviewedAt: now.subtract(const Duration(days: 1)),
        intervalDays: 1,
        easeFactor: 2.4,
        repetitions: 1,
        lapses: 0,
        mastered: false,
        difficulty: DeckDifficulty.facile,
        createdAt: now.subtract(const Duration(days: 12)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      _flashcard(
        id: 'algo-card-1',
        collectionId: 'algo',
        deckId: 'algo-complexity',
        question: 'Quelle complexité correspond à une recherche dichotomique ?',
        correctAnswer: 'O(log n)',
        wrongAnswers: const ['O(n)', 'O(n log n)', 'O(1)'],
        hint: 'On divise l’espace de recherche.',
        explanation: 'La recherche dichotomique réduit de moitié à chaque étape.',
        currentTestMode: TestMode.multipleChoice,
        clozeText: 'La recherche dichotomique a une complexité en {{O(log n)}}.',
        acceptedAnswers: const ['O(log n)', 'log n'],
        source: 'Algo notes',
        level: 2,
        tags: const ['algorithmes'],
        dueAt: now.add(const Duration(days: 1)),
        lastReviewedAt: now.subtract(const Duration(days: 3)),
        intervalDays: 3,
        easeFactor: 2.5,
        repetitions: 2,
        lapses: 0,
        mastered: false,
        difficulty: DeckDifficulty.moyen,
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      _flashcard(
        id: 'sql-card-1',
        collectionId: 'sql',
        deckId: 'sql-joins',
        question: 'Quelle jointure retourne uniquement les lignes correspondantes des deux tables ?',
        correctAnswer: 'INNER JOIN',
        wrongAnswers: const ['LEFT JOIN', 'RIGHT JOIN', 'CROSS JOIN'],
        hint: 'Intersection logique.',
        explanation: 'INNER JOIN garde seulement les correspondances existantes des deux côtés.',
        currentTestMode: TestMode.multipleChoice,
        clozeText: null,
        acceptedAnswers: const ['INNER JOIN', 'INNER'],
        source: 'SQL workbook',
        level: 2,
        tags: const ['sql'],
        dueAt: now.subtract(const Duration(days: 1)),
        lastReviewedAt: now.subtract(const Duration(days: 4)),
        intervalDays: 4,
        easeFactor: 2.7,
        repetitions: 3,
        lapses: 0,
        mastered: true,
        difficulty: DeckDifficulty.moyen,
        createdAt: now.subtract(const Duration(days: 28)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      _flashcard(
        id: 'http-card-1',
        collectionId: 'http',
        deckId: 'http-cache',
        question: 'Quel en-tête HTTP permet de contrôler la mise en cache côté client ?',
        correctAnswer: 'Cache-Control',
        wrongAnswers: const ['Content-Type', 'ETag', 'Accept'],
        hint: 'Il décrit les directives de cache.',
        explanation: 'Cache-Control pilote la durée et les règles de mise en cache côté client et proxy.',
        currentTestMode: TestMode.multipleChoice,
        clozeText: 'Le header {{Cache-Control}} définit les directives de cache.',
        acceptedAnswers: const ['Cache-Control', 'cache-control'],
        source: 'HTTP cheatsheet',
        level: 2,
        tags: const ['http'],
        dueAt: now.add(const Duration(days: 2)),
        lastReviewedAt: now.subtract(const Duration(days: 2)),
        intervalDays: 2,
        easeFactor: 2.3,
        repetitions: 1,
        lapses: 0,
        mastered: false,
        difficulty: DeckDifficulty.moyen,
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }

  FlashcardsCompanion _flashcard({
    required String id,
    required String collectionId,
    required String deckId,
    required String question,
    required String correctAnswer,
    required List<String> wrongAnswers,
    required String? hint,
    required String? explanation,
    required TestMode currentTestMode,
    required String? clozeText,
    required List<String> acceptedAnswers,
    required String source,
    required int level,
    required List<String> tags,
    required DateTime dueAt,
    required DateTime? lastReviewedAt,
    required double intervalDays,
    required double easeFactor,
    required int repetitions,
    required int lapses,
    required bool mastered,
    required DeckDifficulty difficulty,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final allowedModes = _cardModeService.allowedModesFor(
      clozeText: clozeText,
      acceptedAnswers: acceptedAnswers,
    );
    return FlashcardsCompanion.insert(
      id: id,
      collectionId: collectionId,
      deckId: deckId,
      question: question,
      correctAnswer: correctAnswer,
      answer: Value(correctAnswer),
      wrongAnswers: wrongAnswers,
      hint: Value(hint),
      explanation: Value(explanation),
      currentTestMode: currentTestMode,
      allowedTestModes: allowedModes,
      lastTestMode: const Value(null),
      modeHistory: const [TestMode.multipleChoice],
      clozeText: Value(clozeText),
      acceptedAnswers: acceptedAnswers,
      source: Value(source),
      difficulty: Value(difficulty),
      level: level,
      tags: tags,
      dueAt: dueAt,
      lastReviewedAt: Value(lastReviewedAt),
      intervalDays: intervalDays,
      easeFactor: easeFactor,
      repetitions: repetitions,
      lapses: lapses,
      mastered: mastered,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  List<ReviewLogsCompanion> _buildReviewLogs(DateTime now) {
    final entries = <ReviewLogsCompanion>[];
    for (var day = 0; day < 28; day++) {
      final date = now.subtract(Duration(days: day));
      if (day % 5 == 0 || day % 7 == 0) {
        continue;
      }
      final reviewsForDay = 1 + (day % 3);
      for (var reviewIndex = 0; reviewIndex < reviewsForDay; reviewIndex++) {
        final result = ReviewResult.values[(day + reviewIndex) % ReviewResult.values.length];
        entries.add(
          ReviewLogsCompanion.insert(
            id: 'review-$day-$reviewIndex',
            flashcardId: 'react-card-${(day + reviewIndex) % 24}',
            collectionId: 'react',
            deckId: 'react-hooks-base',
            reviewResult: result,
            testMode: TestMode.multipleChoice,
            wasCorrect: result != ReviewResult.again,
            createdAt: date.add(Duration(hours: 8 + reviewIndex)),
            scheduledDueAt: date,
          ),
        );
      }
    }
    return entries;
  }
}

class ColorToken {
  const ColorToken(this.value);

  final int value;
}
