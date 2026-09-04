import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('native SQLite build supports encrypted files', () {
    final directory = Directory.systemTemp.createTempSync('memflow_crypto_');
    final path = '${directory.path}/database.sqlite';
    addTearDown(() => directory.deleteSync(recursive: true));

    final database = sqlite3.open(path);
    expect(database.select('PRAGMA cipher'), isNotEmpty);
    database.execute("PRAGMA key = 'test-key'");
    database.execute(
      "CREATE TABLE secrets (value TEXT); INSERT INTO secrets VALUES ('known-plaintext-marker');",
    );
    database.close();

    final bytes = File(path).readAsBytesSync();
    expect(String.fromCharCodes(bytes.take(16)), isNot(contains('SQLite')));
    expect(
      String.fromCharCodes(bytes),
      isNot(contains('known-plaintext-marker')),
    );

    final correctKey = sqlite3.open(path);
    correctKey.execute("PRAGMA key = 'test-key'");
    expect(correctKey.select('SELECT value FROM secrets').single['value'],
        'known-plaintext-marker');
    correctKey.close();

    final wrongKey = sqlite3.open(path);
    addTearDown(() => wrongKey.close());
    wrongKey.execute("PRAGMA key = 'wrong-key'");
    expect(
      () => wrongKey.select('SELECT * FROM secrets'),
      throwsA(isA<SqliteException>()),
    );
  });
}
