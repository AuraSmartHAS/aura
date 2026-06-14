import 'package:drift/drift.dart';
import 'package:aura/core/database/app_database.dart';
import '../../domain/entities/medication.dart';

/// Drift-backed local store for caregiver medications. Swap for a remote
/// datasource once the backend exposes `/homes/{id}/medications`.
abstract class MedicationLocalDataSource {
  Future<List<Medication>> getMedications(String homeId);
  Future<void> upsert(Medication medication);
  Future<void> delete(String id);
}

class MedicationLocalDataSourceImpl implements MedicationLocalDataSource {
  MedicationLocalDataSourceImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<Medication>> getMedications(String homeId) async {
    final rows = await (_db.select(_db.medications)
          ..where((m) => m.homeId.equals(homeId))
          ..orderBy([(m) => OrderingTerm.asc(m.name)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<void> upsert(Medication medication) {
    return _db.into(_db.medications).insertOnConflictUpdate(
          MedicationsCompanion(
            id: Value(medication.id),
            homeId: Value(medication.homeId),
            name: Value(medication.name),
            dosage: Value(medication.dosage),
            schedule: Value(medication.schedule),
            notes: Value(medication.notes),
          ),
        );
  }

  @override
  Future<void> delete(String id) {
    return (_db.delete(_db.medications)..where((m) => m.id.equals(id))).go();
  }

  Medication _toEntity(MedicationEntry row) {
    return Medication(
      id: row.id,
      homeId: row.homeId,
      name: row.name,
      dosage: row.dosage,
      schedule: row.schedule,
      notes: row.notes,
    );
  }
}
