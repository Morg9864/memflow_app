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

Future<QueryExecutor> openMemFlowConnectionWithKey() async {
  final key = await LocalDatabaseKeyStore().readOrCreate();
  final path = await _databasePath();
  await migratePlaintextDatabase(path, key);
  return NativeDatabase.createInBackground(
    File(path),
    setup: (database) => _configureEncryptedDatabase(database, key),
  );
}

QueryExecutor openMemFlowConnection() =>
    throw StateError('Use AppDatabase.open() for persistent native storage.');

QueryExecutor openMemoryConnection() => NativeDatabase.memory();
