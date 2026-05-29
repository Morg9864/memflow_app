import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

QueryExecutor openMemFlowConnection() {
  return driftDatabase(
    name: 'memflow',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
    native: const DriftNativeOptions(shareAcrossIsolates: true),
  );
}

QueryExecutor openMemoryConnection() => NativeDatabase.memory();
