import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../database_key_store.dart';

String _quotePragmaValue(String value) => value.replaceAll("'", "''");

void _configureEncryptedDatabase(CommonDatabase database, String key) {
  final nativeDatabase = database as sqlite.Database;
  nativeDatabase.execute("PRAGMA key = '${_quotePragmaValue(key)}'");
  if (nativeDatabase.select('PRAGMA cipher').isEmpty) {
    throw StateError('SQLite3MultipleCiphers is not active.');
  }
}

Future<void> migratePlaintextDatabase(String path, String key) async {
  final file = File(path);
  if (!await file.exists() || await file.length() == 0) return;

  final raw = sqlite.sqlite3.open(path);
  try {
    try {
      raw.select('SELECT name FROM sqlite_master LIMIT 1');
    } on sqlite.SqliteException {
      return;
    }
    raw.execute("PRAGMA rekey = '${_quotePragmaValue(key)}'");
    raw.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  } finally {
    raw.close();
  }
}

Future<String> _databasePath() async {
  final directory = await getApplicationDocumentsDirectory();
  return File('${directory.path}/memflow.sqlite').path;
}

void _verifyDatabaseCanBeOpened(String path, String key) {
  final database = sqlite.sqlite3.open(path);
  try {
    _configureEncryptedDatabase(database, key);
    database.select('PRAGMA user_version');
  } finally {
    database.close();
  }
}

Future<void> _preserveUnreadableDatabase(String path) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final backupPath = '$path.unreadable-$timestamp';
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final file = File('$path$suffix');
    if (await file.exists()) {
      await file.rename('$backupPath$suffix');
    }
  }
  // ignore: avoid_print
  print('MemFlow: unreadable local database preserved at $backupPath');
}

Future<QueryExecutor> openMemFlowConnectionWithKey() async {
  final key = await LocalDatabaseKeyStore().readOrCreate();
  final path = await _databasePath();
  await migratePlaintextDatabase(path, key);
  try {
    _verifyDatabaseCanBeOpened(path, key);
  } on sqlite.SqliteException catch (error) {
    if (error.resultCode != 26) rethrow;

    // Android may restore the encrypted database without its installation key.
    // Keep that file intact, then let account sync repopulate a fresh database.
    await _preserveUnreadableDatabase(path);
    _verifyDatabaseCanBeOpened(path, key);
  }
  return NativeDatabase.createInBackground(
    File(path),
    setup: (database) => _configureEncryptedDatabase(database, key),
  );
}

QueryExecutor openMemFlowConnection() =>
    throw StateError('Use AppDatabase.open() for persistent native storage.');

QueryExecutor openMemoryConnection() => NativeDatabase.memory();
