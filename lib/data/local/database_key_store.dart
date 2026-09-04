import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the per-installation database key outside the database itself.
class LocalDatabaseKeyStore {
  LocalDatabaseKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const keyName = 'memflow.local_database_key.v1';
  final FlutterSecureStorage _storage;

  Future<String> readOrCreate() async {
    final existing = await _storage.read(key: keyName);
    if (existing != null) {
      try {
        if (base64.decode(existing).length == 32) return existing;
      } on FormatException {
        // Replace malformed legacy values rather than using a weak key.
      }
    }

    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final generated = base64Encode(bytes);
    await _storage.write(key: keyName, value: generated);
    return generated;
  }
}
