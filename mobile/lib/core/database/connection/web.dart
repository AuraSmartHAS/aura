import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Web executor backed by the sqlite3 WASM build.
///
/// Requires `web/sqlite3.wasm` and `web/drift_worker.js` to be present (served
/// at the site root). Loading is lazy, so the app boots even before the DB is
/// touched; the first query resolves the WASM database.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'aura',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
