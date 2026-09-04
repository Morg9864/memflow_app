import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/models.dart';
import 'connection/connection.dart';

part 'database.g.dart';

class DateTimeConverter extends TypeConverter<DateTime, int> {
  const DateTimeConverter();

  @override
  DateTime fromSql(int fromDb) => DateTime.fromMillisecondsSinceEpoch(fromDb);

  @override
  int toSql(DateTime value) => value.millisecondsSinceEpoch;
}

class NullableDateTimeConverter extends TypeConverter<DateTime?, int?> {
  const NullableDateTimeConverter();

  @override
  DateTime? fromSql(int? fromDb) {
    if (fromDb == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(fromDb);
  }

  @override
  int? toSql(DateTime? value) => value?.millisecondsSinceEpoch;
}

class EnumNameConverter<T extends Enum> extends TypeConverter<T, String> {
  const EnumNameConverter(this.values);

  final List<T> values;

  @override
  T fromSql(String fromDb) =>
      values.firstWhere((value) => value.name == fromDb);

  @override
  String toSql(T value) => value.name;
}

class NullableEnumNameConverter<T extends Enum>
    extends TypeConverter<T?, String?> {
  const NullableEnumNameConverter(this.values);

  final List<T> values;

  @override
  T? fromSql(String? fromDb) {
    if (fromDb == null || fromDb.isEmpty) {
      return null;
    }
    return values.firstWhere((value) => value.name == fromDb);
  }

  @override
  String? toSql(T? value) => value?.name;
}

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    final decoded = jsonDecode(fromDb) as List<dynamic>;
    return decoded.map((item) => item.toString()).toList();
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

class TestModeListConverter extends TypeConverter<List<TestMode>, String> {
  const TestModeListConverter();

  @override
  List<TestMode> fromSql(String fromDb) {
    final decoded = jsonDecode(fromDb) as List<dynamic>;
    return decoded
        .map((item) => TestMode.values.firstWhere((mode) => mode.name == item))
        .toList();
  }

  @override
  String toSql(List<TestMode> value) =>
      jsonEncode(value.map((mode) => mode.name).toList());
}

@DataClassName('Collection')
class Collections extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get description => text()();

  TextColumn get icon => text()();

  IntColumn get color => integer()();

  BoolColumn get isDisabled => boolean().withDefault(const Constant(false))();

  IntColumn get createdAt => integer().map(const DateTimeConverter())();

  IntColumn get updatedAt => integer().map(const DateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('Deck')
class Decks extends Table {
  TextColumn get id => text()();

  TextColumn get collectionId => text().references(Collections, #id)();

  TextColumn get name => text()();

  TextColumn get icon => text()();

  TextColumn get difficulty =>
      text().map(const EnumNameConverter(DeckDifficulty.values))();

  BoolColumn get isDisabled => boolean().withDefault(const Constant(false))();

  IntColumn get createdAt => integer().map(const DateTimeConverter())();

  IntColumn get updatedAt => integer().map(const DateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('Flashcard')
class Flashcards extends Table {
  TextColumn get id => text()();

  TextColumn get collectionId => text().references(Collections, #id)();

  TextColumn get deckId => text().references(Decks, #id)();

  TextColumn get question => text()();

  TextColumn get correctAnswer => text()();

  TextColumn get answer => text().nullable()();

  TextColumn get wrongAnswers => text().map(const StringListConverter())();

  TextColumn get hint => text().nullable()();

  TextColumn get explanation => text().nullable()();

  TextColumn get currentTestMode =>
      text().map(const EnumNameConverter(TestMode.values))();

  TextColumn get allowedTestModes =>
      text().map(const TestModeListConverter())();

  TextColumn get lastTestMode =>
      text().nullable().map(const NullableEnumNameConverter(TestMode.values))();

  TextColumn get modeHistory => text().map(const TestModeListConverter())();

  TextColumn get clozeText => text().nullable()();

  TextColumn get clozeAnswers => text().map(const StringListConverter())();

  TextColumn get clozeWordBank => text().map(const StringListConverter())();

  TextColumn get acceptedAnswers => text().map(const StringListConverter())();

  TextColumn get source => text().nullable()();

  TextColumn get difficulty => text().nullable().map(
    const NullableEnumNameConverter(DeckDifficulty.values),
  )();

  IntColumn get level => integer()();

  TextColumn get tags => text().map(const StringListConverter())();

  IntColumn get dueAt => integer().map(const DateTimeConverter())();

  IntColumn get lastReviewedAt =>
      integer().nullable().map(const NullableDateTimeConverter())();

  RealColumn get intervalDays => real()();

  RealColumn get easeFactor => real()();

  IntColumn get repetitions => integer()();

  IntColumn get lapses => integer()();

  BoolColumn get mastered => boolean()();

  IntColumn get createdAt => integer().map(const DateTimeConverter())();

  IntColumn get updatedAt => integer().map(const DateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ReviewLog')
class ReviewLogs extends Table {
  TextColumn get id => text()();

  TextColumn get flashcardId => text().references(Flashcards, #id)();

  TextColumn get collectionId => text().references(Collections, #id)();

  TextColumn get deckId => text().references(Decks, #id)();

  TextColumn get reviewResult =>
      text().map(const EnumNameConverter(ReviewResult.values))();

  TextColumn get testMode =>
      text().map(const EnumNameConverter(TestMode.values))();

  BoolColumn get wasCorrect => boolean()();

  IntColumn get createdAt => integer().map(const DateTimeConverter())();

  IntColumn get scheduledDueAt => integer().map(const DateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Intention d'écriture locale pas encore poussée. Elle ne porte pas de copie
/// de la ligne : au moment du push, l'état local fait foi et est sérialisé à
/// la volée. Une copie ici divergerait de la ligne à la première réécriture.
@DataClassName('SyncQueueEntry')
class SyncQueueEntries extends Table {
  TextColumn get id => text()();

  TextColumn get entityType =>
      text().map(const EnumNameConverter(SyncEntityType.values))();

  TextColumn get entityId => text()();

  TextColumn get operation =>
      text().map(const EnumNameConverter(SyncOperation.values))();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  IntColumn get updatedAt => integer().map(const DateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AppMeta')
class AppMetaEntries extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Collections,
    Decks,
    Flashcards,
    ReviewLogs,
    SyncQueueEntries,
    AppMetaEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? openMemFlowConnection());

  static Future<AppDatabase> open() async {
    final executor = await openMemFlowConnectionWithKey();
    return AppDatabase(executor);
  }

  AppDatabase.memory() : super(openMemoryConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (migrator) => migrator.createAll());

  static const ownerKey = 'owner_user_id';
  static const reviewLogCursorKey = 'review_log_cursor';

  Future<bool> isEmpty() async {
    final row = await customSelect(
      'SELECT COUNT(*) AS c FROM collections',
    ).getSingle();
    return row.read<int>('c') == 0;
  }

  /// Le stockage local n'appartient qu'à un seul compte. Si l'utilisateur
  /// change, on repart d'une base vide plutôt que de mélanger deux jeux de
  /// données sur le même appareil. Retourne `true` si la base a été purgée.
  Future<bool> adoptOwner(String userId) async {
    final currentOwner = await readMetaString(ownerKey);
    if (currentOwner == userId) {
      return false;
    }
    await clearAllUserData();
    await writeMetaString(ownerKey, userId);
    return true;
  }

  /// Supprime les lignes devenues orphelines après une réconciliation : quand
  /// un autre appareil supprime un deck, la cascade distante emporte ses
  /// cartes, mais la réconciliation locale ne voit que les identifiants
  /// disparus de la table qu'elle compare.
  Future<void> deleteOrphans() async {
    await customStatement(
      'DELETE FROM decks WHERE collection_id NOT IN (SELECT id FROM collections)',
    );
    await customStatement(
      'DELETE FROM flashcards WHERE deck_id NOT IN (SELECT id FROM decks) '
      'OR collection_id NOT IN (SELECT id FROM collections)',
    );
    await customStatement(
      'DELETE FROM review_logs WHERE flashcard_id NOT IN (SELECT id FROM flashcards)',
    );
  }

  Future<void> clearAllUserData() async {
    await transaction(() async {
      await delete(reviewLogs).go();
      await delete(flashcards).go();
      await delete(decks).go();
      await delete(collections).go();
      await delete(syncQueueEntries).go();
      await delete(appMetaEntries).go();
    });
  }

  /// Une entité n'a qu'une seule intention en attente : réécrire la même carte
  /// dix fois hors ligne ne produit qu'un seul push, et un `delete` remplace
  /// naturellement un `upsert` non parti.
  Future<void> enqueueSync({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperation operation,
  }) async {
    await into(syncQueueEntries).insertOnConflictUpdate(
      SyncQueueEntriesCompanion.insert(
        id: '${entityType.name}-$entityId',
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<List<SyncQueueEntry>> pendingSyncEntries() {
    return (select(
      syncQueueEntries,
    )..orderBy([(table) => OrderingTerm(expression: table.updatedAt)])).get();
  }

  Future<void> deleteSyncQueueEntry(String id) {
    return (delete(
      syncQueueEntries,
    )..where((table) => table.id.equals(id))).go();
  }

  Future<void> incrementSyncQueueAttempts(String id) async {
    final entry = await (select(
      syncQueueEntries,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (entry == null) {
      return;
    }

    await update(syncQueueEntries).replace(
      entry.copyWith(attempts: entry.attempts + 1, updatedAt: DateTime.now()),
    );
  }

  Future<void> writeMetaDateTime(String key, DateTime value) async {
    await into(appMetaEntries).insertOnConflictUpdate(
      AppMetaEntriesCompanion.insert(key: key, value: value.toIso8601String()),
    );
  }

  Future<DateTime?> readMetaDateTime(String key) async {
    final meta = await (select(
      appMetaEntries,
    )..where((table) => table.key.equals(key))).getSingleOrNull();
    return meta == null ? null : DateTime.tryParse(meta.value);
  }

  Future<void> writeMetaString(String key, String value) async {
    await into(appMetaEntries).insertOnConflictUpdate(
      AppMetaEntriesCompanion.insert(key: key, value: value),
    );
  }

  Future<String?> readMetaString(String key) async {
    final meta = await (select(
      appMetaEntries,
    )..where((table) => table.key.equals(key))).getSingleOrNull();
    return meta?.value;
  }

  Future<void> deleteMeta(String key) {
    return (delete(
      appMetaEntries,
    )..where((table) => table.key.equals(key))).go();
  }

  Future<DateTime?> readEntityUpdatedAt(
    SyncEntityType entityType,
    String entityId,
  ) async {
    switch (entityType) {
      case SyncEntityType.collection:
        return (await (select(
              collections,
            )..where((table) => table.id.equals(entityId))).getSingleOrNull())
            ?.updatedAt;
      case SyncEntityType.deck:
        return (await (select(
              decks,
            )..where((table) => table.id.equals(entityId))).getSingleOrNull())
            ?.updatedAt;
      case SyncEntityType.flashcard:
        return (await (select(
              flashcards,
            )..where((table) => table.id.equals(entityId))).getSingleOrNull())
            ?.updatedAt;
      case SyncEntityType.reviewLog:
        return (await (select(
              reviewLogs,
            )..where((table) => table.id.equals(entityId))).getSingleOrNull())
            ?.createdAt;
    }
  }

  Future<void> applyRemoteRecord(RemoteSyncRecord record) async {
    switch (record.entityType) {
      case SyncEntityType.collection:
        await into(
          collections,
        ).insertOnConflictUpdate(_collectionFromPayload(record.payload));
      case SyncEntityType.deck:
        await into(
          decks,
        ).insertOnConflictUpdate(_deckFromPayload(record.payload));
      case SyncEntityType.flashcard:
        await into(
          flashcards,
        ).insertOnConflictUpdate(_flashcardFromPayload(record.payload));
      case SyncEntityType.reviewLog:
        await into(
          reviewLogs,
        ).insertOnConflictUpdate(_reviewLogFromPayload(record.payload));
    }
  }

  CollectionsCompanion _collectionFromPayload(Map<String, dynamic> payload) {
    return CollectionsCompanion.insert(
      id: payload['id'] as String,
      name: payload['name'] as String,
      description: payload['description'] as String? ?? '',
      icon: payload['icon'] as String,
      color: (payload['color'] as num).toInt(),
      isDisabled: Value(payload['is_disabled'] as bool? ?? false),
      createdAt: DateTime.parse(payload['created_at'] as String),
      updatedAt: DateTime.parse(payload['updated_at'] as String),
    );
  }

  DecksCompanion _deckFromPayload(Map<String, dynamic> payload) {
    return DecksCompanion.insert(
      id: payload['id'] as String,
      collectionId: payload['collection_id'] as String,
      name: payload['name'] as String,
      icon: payload['icon'] as String,
      difficulty: DeckDifficulty.values.firstWhere(
        (value) => value.name == payload['difficulty'],
        orElse: () => DeckDifficulty.facile,
      ),
      isDisabled: Value(payload['is_disabled'] as bool? ?? false),
      createdAt: DateTime.parse(payload['created_at'] as String),
      updatedAt: DateTime.parse(payload['updated_at'] as String),
    );
  }

  FlashcardsCompanion _flashcardFromPayload(Map<String, dynamic> payload) {
    return FlashcardsCompanion.insert(
      id: payload['id'] as String,
      collectionId: payload['collection_id'] as String,
      deckId: payload['deck_id'] as String,
      question: payload['question'] as String,
      correctAnswer: payload['correct_answer'] as String,
      answer: Value(payload['answer'] as String?),
      wrongAnswers: _stringList(payload['wrong_answers']),
      hint: Value(payload['hint'] as String?),
      explanation: Value(payload['explanation'] as String?),
      currentTestMode:
          _testMode(payload['current_test_mode']) ?? TestMode.multipleChoice,
      allowedTestModes: _testModeList(payload['allowed_test_modes']),
      lastTestMode: Value(_testMode(payload['last_test_mode'])),
      modeHistory: _testModeList(payload['mode_history']),
      clozeText: Value(payload['cloze_text'] as String?),
      clozeAnswers: _stringList(payload['cloze_answers']),
      clozeWordBank: _stringList(payload['cloze_word_bank']),
      acceptedAnswers: _stringList(payload['accepted_answers']),
      source: Value(payload['source'] as String?),
      difficulty: Value(
        payload['difficulty'] == null
            ? null
            : DeckDifficulty.values.firstWhere(
                (value) => value.name == payload['difficulty'],
              ),
      ),
      level: (payload['level'] as num).toInt(),
      tags: _stringList(payload['tags']),
      dueAt: DateTime.parse(payload['due_at'] as String),
      lastReviewedAt: Value(
        payload['last_reviewed_at'] == null
            ? null
            : DateTime.parse(payload['last_reviewed_at'] as String),
      ),
      intervalDays: (payload['interval_days'] as num).toDouble(),
      easeFactor: (payload['ease_factor'] as num).toDouble(),
      repetitions: payload['repetitions'] as int,
      lapses: payload['lapses'] as int,
      mastered: payload['mastered'] as bool,
      createdAt: DateTime.parse(payload['created_at'] as String),
      updatedAt: DateTime.parse(payload['updated_at'] as String),
    );
  }

  ReviewLogsCompanion _reviewLogFromPayload(Map<String, dynamic> payload) {
    return ReviewLogsCompanion.insert(
      id: payload['id'] as String,
      flashcardId: payload['flashcard_id'] as String,
      collectionId: payload['collection_id'] as String,
      deckId: payload['deck_id'] as String,
      reviewResult: ReviewResult.values.firstWhere(
        (value) => value.name == payload['review_result'],
        orElse: () => ReviewResult.good,
      ),
      testMode: _testMode(payload['test_mode']) ?? TestMode.multipleChoice,
      wasCorrect: payload['was_correct'] as bool,
      createdAt: DateTime.parse(payload['created_at'] as String),
      scheduledDueAt: DateTime.parse(payload['scheduled_due_at'] as String),
    );
  }

  /// Les payloads distants peuvent contenir des modes retirés du domaine
  /// (`ordering`, `matching` d'anciennes versions) : on les ignore plutôt que
  /// de faire échouer toute la synchronisation sur une ligne.
  static TestMode? _testMode(Object? raw) {
    if (raw == null) {
      return null;
    }
    for (final mode in TestMode.values) {
      if (mode.name == raw) {
        return mode;
      }
    }
    return null;
  }

  static List<TestMode> _testModeList(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw.map(_testMode).whereType<TestMode>().toList();
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw.map((item) => item.toString()).toList();
  }
}
