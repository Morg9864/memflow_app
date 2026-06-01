import 'package:flutter/material.dart';

enum TestMode {
  multipleChoice,
  classicFlashcard,
  reversedFlashcard,
  cloze,
  freeText,
  trueFalse,
  ordering,
  matching,
}

enum ReviewResult { again, hard, good, easy }

enum DeckDifficulty { facile, moyen, avance }

enum DeckStatus { nouveau, maitrise, dues }

enum ThemePreference { system, light, dark }

enum SyncEntityType { collection, deck, flashcard, reviewLog }

enum SyncOperation { upsert, delete }

class RemoteSyncRecord {
  const RemoteSyncRecord({
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.updatedAt,
  });

  final SyncEntityType entityType;
  final String entityId;
  final Map<String, dynamic> payload;
  final DateTime updatedAt;
}

extension TestModeX on TestMode {
  String get label => switch (this) {
    TestMode.multipleChoice => 'QCM',
    TestMode.classicFlashcard => 'Flashcard',
    TestMode.reversedFlashcard => 'Flashcard inversée',
    TestMode.cloze => 'Texte à trous',
    TestMode.freeText => 'Saisie libre',
    TestMode.trueFalse => 'Vrai / faux',
    TestMode.ordering => 'Ordonnancement',
    TestMode.matching => 'Association',
  };
}

extension ReviewResultX on ReviewResult {
  String get label => switch (this) {
    ReviewResult.again => 'Encore',
    ReviewResult.hard => 'Difficile',
    ReviewResult.good => 'Correct',
    ReviewResult.easy => 'Facile',
  };

  String get description => switch (this) {
    ReviewResult.again => 'Je ne savais pas',
    ReviewResult.hard => 'Avec effort',
    ReviewResult.good => 'Je savais',
    ReviewResult.easy => 'Trop simple',
  };

  Color tone(ColorScheme scheme) => switch (this) {
    ReviewResult.again => const Color(0xFFD94A3A),
    ReviewResult.hard => const Color(0xFFE8792F),
    ReviewResult.good => const Color(0xFF4D9461),
    ReviewResult.easy => const Color(0xFF4D79B5),
  };

  Color background(ColorScheme scheme) => switch (this) {
    ReviewResult.again => const Color(0xFFFBE7E4),
    ReviewResult.hard => const Color(0xFFFCE9DC),
    ReviewResult.good => const Color(0xFFEAF3E7),
    ReviewResult.easy => const Color(0xFFEAF0F3),
  };
}

extension DeckDifficultyX on DeckDifficulty {
  String get label => switch (this) {
    DeckDifficulty.facile => 'Facile',
    DeckDifficulty.moyen => 'Moyen',
    DeckDifficulty.avance => 'Avancé',
  };
}

extension DeckStatusX on DeckStatus {
  String get label => switch (this) {
    DeckStatus.nouveau => 'Nouveau',
    DeckStatus.maitrise => 'Maîtrisé',
    DeckStatus.dues => 'Dues',
  };
}

extension ThemePreferenceX on ThemePreference {
  ThemeMode get themeMode => switch (this) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  String get label => switch (this) {
    ThemePreference.system => 'Système',
    ThemePreference.light => 'Clair',
    ThemePreference.dark => 'Sombre',
  };
}

class HomeStats {
  const HomeStats({
    required this.streakDays,
    required this.successRate,
    required this.dueCards,
    required this.totalCardsSeen,
  });

  final int streakDays;
  final double successRate;
  final int dueCards;
  final int totalCardsSeen;
}

class CollectionListItem {
  const CollectionListItem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.totalCards,
    required this.cardsDone,
    required this.dueCards,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    required this.errorCount,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final int totalCards;
  final int cardsDone;
  final int dueCards;
  final int color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int errorCount;

  double get progress => totalCards == 0 ? 0 : cardsDone / totalCards;
}

class CollectionDetailData {
  const CollectionDetailData({required this.collection, required this.decks});

  final CollectionListItem collection;
  final List<DeckListItem> decks;
}

class DeckListItem {
  const DeckListItem({
    required this.id,
    required this.collectionId,
    required this.name,
    required this.icon,
    required this.difficulty,
    required this.totalCards,
    required this.cardsDone,
    required this.dueCards,
    required this.progress,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String collectionId;
  final String name;
  final String icon;
  final DeckDifficulty difficulty;
  final int totalCards;
  final int cardsDone;
  final int dueCards;
  final double progress;
  final DeckStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get badgeLabel {
    if (status == DeckStatus.dues && dueCards > 0) {
      return '$dueCards dues';
    }
    return status.label;
  }
}

class CollectionRecord {
  const CollectionRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final int color;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class DeckRecord {
  const DeckRecord({
    required this.id,
    required this.collectionId,
    required this.name,
    required this.icon,
    required this.difficulty,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String collectionId;
  final String name;
  final String icon;
  final DeckDifficulty difficulty;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class FlashcardRecord {
  const FlashcardRecord({
    required this.id,
    required this.collectionId,
    required this.deckId,
    required this.question,
    required this.correctAnswer,
    required this.answer,
    required this.wrongAnswers,
    required this.hint,
    required this.explanation,
    required this.currentTestMode,
    required this.allowedTestModes,
    required this.lastTestMode,
    required this.modeHistory,
    required this.clozeText,
    required this.clozeAnswers,
    required this.clozeWordBank,
    required this.acceptedAnswers,
    required this.source,
    required this.difficulty,
    required this.level,
    required this.tags,
    required this.dueAt,
    required this.lastReviewedAt,
    required this.intervalDays,
    required this.easeFactor,
    required this.repetitions,
    required this.lapses,
    required this.mastered,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String collectionId;
  final String deckId;
  final String question;
  final String correctAnswer;
  final String? answer;
  final List<String> wrongAnswers;
  final String? hint;
  final String? explanation;
  final TestMode currentTestMode;
  final List<TestMode> allowedTestModes;
  final TestMode? lastTestMode;
  final List<TestMode> modeHistory;
  final String? clozeText;
  final List<String> clozeAnswers;
  final List<String> clozeWordBank;
  final List<String> acceptedAnswers;
  final String? source;
  final DeckDifficulty? difficulty;
  final int level;
  final List<String> tags;
  final DateTime dueAt;
  final DateTime? lastReviewedAt;
  final double intervalDays;
  final double easeFactor;
  final int repetitions;
  final int lapses;
  final bool mastered;
  final DateTime createdAt;
  final DateTime updatedAt;

  FlashcardRecord copyWith({
    String? id,
    String? collectionId,
    String? deckId,
    String? question,
    String? correctAnswer,
    String? answer,
    List<String>? wrongAnswers,
    String? hint,
    String? explanation,
    TestMode? currentTestMode,
    List<TestMode>? allowedTestModes,
    TestMode? lastTestMode,
    List<TestMode>? modeHistory,
    String? clozeText,
    List<String>? clozeAnswers,
    List<String>? clozeWordBank,
    List<String>? acceptedAnswers,
    String? source,
    DeckDifficulty? difficulty,
    int? level,
    List<String>? tags,
    DateTime? dueAt,
    DateTime? lastReviewedAt,
    double? intervalDays,
    double? easeFactor,
    int? repetitions,
    int? lapses,
    bool? mastered,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FlashcardRecord(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      deckId: deckId ?? this.deckId,
      question: question ?? this.question,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      answer: answer ?? this.answer,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
      hint: hint ?? this.hint,
      explanation: explanation ?? this.explanation,
      currentTestMode: currentTestMode ?? this.currentTestMode,
      allowedTestModes: allowedTestModes ?? this.allowedTestModes,
      lastTestMode: lastTestMode ?? this.lastTestMode,
      modeHistory: modeHistory ?? this.modeHistory,
      clozeText: clozeText ?? this.clozeText,
      clozeAnswers: clozeAnswers ?? this.clozeAnswers,
      clozeWordBank: clozeWordBank ?? this.clozeWordBank,
      acceptedAnswers: acceptedAnswers ?? this.acceptedAnswers,
      source: source ?? this.source,
      difficulty: difficulty ?? this.difficulty,
      level: level ?? this.level,
      tags: tags ?? this.tags,
      dueAt: dueAt ?? this.dueAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      intervalDays: intervalDays ?? this.intervalDays,
      easeFactor: easeFactor ?? this.easeFactor,
      repetitions: repetitions ?? this.repetitions,
      lapses: lapses ?? this.lapses,
      mastered: mastered ?? this.mastered,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ReviewLogRecord {
  const ReviewLogRecord({
    required this.id,
    required this.flashcardId,
    required this.collectionId,
    required this.deckId,
    required this.reviewResult,
    required this.testMode,
    required this.wasCorrect,
    required this.createdAt,
    required this.scheduledDueAt,
  });

  final String id;
  final String flashcardId;
  final String collectionId;
  final String deckId;
  final ReviewResult reviewResult;
  final TestMode testMode;
  final bool wasCorrect;
  final DateTime createdAt;
  final DateTime scheduledDueAt;
}

class HeatmapCell {
  const HeatmapCell({
    required this.label,
    required this.count,
    required this.isActive,
  });

  final String label;
  final int count;
  final bool isActive;
}

class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.progress,
    required this.icon,
  });

  final int level;
  final String title;
  final String subtitle;
  final int count;
  final double progress;
  final IconData icon;
}

class StatisticsOverview {
  const StatisticsOverview({
    required this.streakDays,
    required this.totalReviews,
    required this.successRate,
    required this.studyDays,
    required this.heatmap,
    required this.levelProgress,
  });

  final int streakDays;
  final int totalReviews;
  final double successRate;
  final int studyDays;
  final List<List<HeatmapCell>> heatmap;
  final List<LevelProgress> levelProgress;
}

class CsvImportIssue {
  const CsvImportIssue({required this.rowNumber, required this.message});

  final int rowNumber;
  final String message;
}

class CsvImportCardDraft {
  const CsvImportCardDraft({
    required this.collection,
    required this.deck,
    required this.question,
    required this.correctAnswer,
    required this.wrongAnswers,
    required this.hint,
    required this.explanation,
    required this.level,
    required this.difficulty,
    required this.tags,
    required this.source,
    required this.clozeText,
    required this.clozeAnswers,
    required this.clozeWordBank,
    required this.acceptedAnswers,
    required this.allowedTestModes,
  });

  final String collection;
  final String deck;
  final String question;
  final String correctAnswer;
  final List<String> wrongAnswers;
  final String? hint;
  final String? explanation;
  final int level;
  final DeckDifficulty difficulty;
  final List<String> tags;
  final String? source;
  final String? clozeText;
  final List<String> clozeAnswers;
  final List<String> clozeWordBank;
  final List<String> acceptedAnswers;
  final List<TestMode> allowedTestModes;
}

class CsvImportPreview {
  const CsvImportPreview({
    required this.cards,
    required this.issues,
    required this.delimiter,
    required this.withHeader,
  });

  final List<CsvImportCardDraft> cards;
  final List<CsvImportIssue> issues;
  final String delimiter;
  final bool withHeader;

  bool get isValid => cards.isNotEmpty && issues.isEmpty;
}

class StudySessionState {
  const StudySessionState({
    required this.deckTitle,
    required this.collectionId,
    required this.deckId,
    required this.cards,
    required this.sessionCardIds,
    required this.seenCardIds,
    required this.pendingReviewResults,
    required this.currentIndex,
    required this.revealed,
    required this.selectedOptionIndex,
    required this.hasValidatedAnswer,
    required this.freeTextAnswer,
    required this.reviewCounts,
    required this.currentAnswerWasCorrect,
    required this.isCompleted,
    this.trueFalseProposition,
  });

  final String deckTitle;
  final String? collectionId;
  final String? deckId;
  final List<StudyCard> cards;
  final Set<String> sessionCardIds;
  final Set<String> seenCardIds;
  final Map<String, ReviewResult> pendingReviewResults;
  final int currentIndex;
  final bool revealed;
  final int? selectedOptionIndex;
  final bool hasValidatedAnswer;
  final String freeTextAnswer;
  final Map<ReviewResult, int> reviewCounts;
  final bool? currentAnswerWasCorrect;
  final bool isCompleted;

  /// Proposition affichée pour le mode vrai/faux, tirée au sort parmi la bonne
  /// réponse et les mauvaises réponses. Reste stable tant que la carte courante
  /// ne change pas. `null` pour les autres modes.
  final String? trueFalseProposition;

  StudyCard get currentCard => cards[currentIndex];

  bool get hasSeenAllCards => seenCardIds.length >= sessionCardIds.length;

  int get seenCount => currentIndex + (isCompleted ? 1 : 0);

  double get progress => cards.isEmpty ? 0 : (currentIndex + 1) / cards.length;

  StudySessionState copyWith({
    String? deckTitle,
    String? collectionId,
    String? deckId,
    List<StudyCard>? cards,
    Set<String>? sessionCardIds,
    Set<String>? seenCardIds,
    Map<String, ReviewResult>? pendingReviewResults,
    int? currentIndex,
    bool? revealed,
    int? selectedOptionIndex,
    bool? hasValidatedAnswer,
    String? freeTextAnswer,
    Map<ReviewResult, int>? reviewCounts,
    bool? currentAnswerWasCorrect,
    bool clearSelectedOption = false,
    bool clearCorrectness = false,
    bool? isCompleted,
    String? trueFalseProposition,
    bool clearTrueFalseProposition = false,
  }) {
    return StudySessionState(
      deckTitle: deckTitle ?? this.deckTitle,
      collectionId: collectionId ?? this.collectionId,
      deckId: deckId ?? this.deckId,
      cards: cards ?? this.cards,
      sessionCardIds: sessionCardIds ?? this.sessionCardIds,
      seenCardIds: seenCardIds ?? this.seenCardIds,
      pendingReviewResults: pendingReviewResults ?? this.pendingReviewResults,
      currentIndex: currentIndex ?? this.currentIndex,
      revealed: revealed ?? this.revealed,
      selectedOptionIndex: clearSelectedOption
          ? null
          : (selectedOptionIndex ?? this.selectedOptionIndex),
      hasValidatedAnswer: hasValidatedAnswer ?? this.hasValidatedAnswer,
      freeTextAnswer: freeTextAnswer ?? this.freeTextAnswer,
      reviewCounts: reviewCounts ?? this.reviewCounts,
      currentAnswerWasCorrect: clearCorrectness
          ? null
          : (currentAnswerWasCorrect ?? this.currentAnswerWasCorrect),
      isCompleted: isCompleted ?? this.isCompleted,
      trueFalseProposition: clearTrueFalseProposition
          ? null
          : (trueFalseProposition ?? this.trueFalseProposition),
    );
  }
}

class StudyCard {
  const StudyCard({
    required this.id,
    required this.collectionId,
    required this.deckId,
    required this.question,
    required this.correctAnswer,
    required this.wrongAnswers,
    required this.hint,
    required this.explanation,
    required this.currentTestMode,
    required this.allowedTestModes,
    required this.clozeText,
    required this.clozeAnswers,
    required this.clozeWordBank,
    required this.acceptedAnswers,
    required this.level,
    required this.progressDots,
  });

  final String id;
  final String collectionId;
  final String deckId;
  final String question;
  final String correctAnswer;
  final List<String> wrongAnswers;
  final String? hint;
  final String? explanation;
  final TestMode currentTestMode;
  final List<TestMode> allowedTestModes;
  final String? clozeText;
  final List<String> clozeAnswers;
  final List<String> clozeWordBank;
  final List<String> acceptedAnswers;
  final int level;
  final int progressDots;

  List<String> buildOptions() {
    final options = <String>[correctAnswer, ...wrongAnswers];
    options.sort((a, b) => a.hashCode.compareTo(b.hashCode));
    return options;
  }
}

class FlashcardSummary {
  const FlashcardSummary({
    required this.id,
    required this.deckId,
    required this.collectionId,
    required this.question,
    required this.correctAnswer,
  });

  final String id;
  final String deckId;
  final String collectionId;
  final String question;
  final String correctAnswer;
}

class FlashcardDueItem {
  const FlashcardDueItem({
    required this.id,
    required this.deckId,
    required this.deckName,
    required this.question,
    required this.dueAt,
    required this.isDueNow,
  });

  final String id;
  final String deckId;
  final String deckName;
  final String question;
  final DateTime dueAt;
  final bool isDueNow;
}

class SessionSummary {
  const SessionSummary({
    required this.collectionId,
    required this.deckId,
    required this.deckTitle,
    required this.totalCards,
    required this.reviewCounts,
  });

  final String? collectionId;
  final String? deckId;
  final String deckTitle;
  final int totalCards;
  final Map<ReviewResult, int> reviewCounts;

  int get successCount =>
      (reviewCounts[ReviewResult.good] ?? 0) +
      (reviewCounts[ReviewResult.easy] ?? 0);

  double get successRate => totalCards == 0 ? 0 : successCount / totalCards;
}
