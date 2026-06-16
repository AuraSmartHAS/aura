import 'package:drift/drift.dart';

import 'connection/connection.dart';

part 'app_database.g.dart';

class TranscriptMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get message => text()();
  BoolColumn get isUser => boolean()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Caregiver-managed medications. Local-only for now (no backend route yet —
/// see docs/PROPOSTA-medications-api.md). Schema mirrors the proposed REST DTO
/// so the local datasource can be swapped for a remote one later.
@DataClassName('MedicationEntry')
class Medications extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text()();
  TextColumn get name => text()();
  TextColumn get dosage => text().nullable()();
  TextColumn get schedule => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [TranscriptMessages, Medications])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(medications);
          }
        },
      );
}
