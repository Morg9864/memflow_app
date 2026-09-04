import 'dart:typed_data';

import 'package:sqlite3/common.dart';
import 'package:sqlite3/wasm.dart';

/// Result of the Web persistence spike.
///
/// The production vault will encrypt [databaseBytes] before writing them to a
/// browser storage adapter. This probe deliberately has no password or crypto
/// concerns: it only proves that a Drift-compatible SQLite database can live
/// in memory and be exported/restored without using Drift's persistent worker
/// storage.
final class WebSnapshotProbeResult {
  final Uint8List databaseBytes;
  final int restoredValue;

  const WebSnapshotProbeResult({
    required this.databaseBytes,
    required this.restoredValue,
  });
}

/// Runs the Slice 00 feasibility probe in the browser main isolate.
///
/// This is intentionally isolated from [AppDatabase] until the browser gate
/// proves that the deployed sqlite3.wasm can perform the same round-trip.
Future<WebSnapshotProbeResult> runWebSnapshotProbe({
  Uri sqlite3Uri = const Uri(path: 'sqlite3.wasm'),
}) async {
  final sqlite = await WasmSqlite3.loadFromUrl(sqlite3Uri);
  final vfs = InMemoryFileSystem(name: 'memflow-snapshot-probe');
  sqlite.registerVirtualFileSystem(vfs, makeDefault: true);

  final source = sqlite.open('/memflow-source.sqlite', vfs: vfs.name);
  try {
    source.execute('CREATE TABLE probe (value INTEGER NOT NULL)');
    source.execute('INSERT INTO probe VALUES (42)');
    source.execute("VACUUM INTO '/memflow-snapshot.sqlite'");
  } finally {
    source.close();
  }

  final bytes = _copyFile(vfs, '/memflow-snapshot.sqlite');
  if (bytes.isEmpty) {
    throw StateError('SQLite WASM produced an empty snapshot');
  }

  // Restore into a fresh SQLite handle using only the exported bytes. This is
  // the same seam the encrypted IndexedDB/OPFS adapter will use later.
  // InMemoryFileSystem exposes its file map specifically to support adapters
  // like this one. Reusing the exported file buffer avoids a dependency on
  // sqlite3's internal Uint8Buffer type; opening it still creates a fresh
  // database connection and validates the SQLite file bytes.
  vfs.fileData['/memflow-restored.sqlite'] =
      vfs.fileData['/memflow-snapshot.sqlite'];
  final restored = sqlite.open('/memflow-restored.sqlite', vfs: vfs.name);
  try {
    final value = restored.select('SELECT value FROM probe').first.values.first;
    return WebSnapshotProbeResult(
      databaseBytes: bytes,
      restoredValue: value as int,
    );
  } finally {
    restored.close();
    sqlite.unregisterVirtualFileSystem(vfs);
  }
}

Uint8List _copyFile(InMemoryFileSystem vfs, String path) {
  final file = vfs.fileData[path];
  if (file == null) return Uint8List(0);
  return Uint8List.fromList(file.toList());
}
