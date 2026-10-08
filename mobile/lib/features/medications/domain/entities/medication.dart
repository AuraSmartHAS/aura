import 'package:equatable/equatable.dart';

/// A medication of the home, as the server holds it
/// (`GET /homes/{homeId}/medications`). The server is the source of truth.
class Medication extends Equatable {
  const Medication({
    required this.id,
    required this.homeId,
    required this.name,
    this.dosage,
    this.times = const [],
    this.notes,
    this.active = true,
    this.stockDoses,
  });

  final String id;
  final String homeId;
  final String name;
  final String? dosage;

  /// Dose times in 24h `HH:mm` (e.g. `["08:00", "20:00"]`).
  final List<String> times;
  final String? notes;
  final bool active;

  /// Home stock in doses; null means the stock is not tracked.
  final int? stockDoses;

  /// Times joined for display ("08:00, 20:00"); null when there is none.
  String? get schedule => times.isEmpty ? null : times.join(', ');

  Medication copyWith({int? stockDoses}) {
    return Medication(
      id: id,
      homeId: homeId,
      name: name,
      dosage: dosage,
      times: times,
      notes: notes,
      active: active,
      stockDoses: stockDoses ?? this.stockDoses,
    );
  }

  @override
  List<Object?> get props =>
      [id, homeId, name, dosage, times, notes, active, stockDoses];
}

/// What the caregiver fills in the form, sent on create/update.
class MedicationInput extends Equatable {
  const MedicationInput({
    required this.name,
    this.dosage,
    this.times = const [],
    this.notes,
    this.stockDoses,
  });

  final String name;
  final String? dosage;
  final List<String> times;
  final String? notes;
  final int? stockDoses;

  @override
  List<Object?> get props => [name, dosage, times, notes, stockDoses];
}

/// Result of `POST /medications/{id}/confirm`.
class DoseConfirmation extends Equatable {
  const DoseConfirmation({
    required this.signalId,
    required this.taken,
    this.stockDoses,
  });

  final String signalId;
  final bool taken;

  /// Stock after the confirmation (already decremented when taken).
  final int? stockDoses;

  @override
  List<Object?> get props => [signalId, taken, stockDoses];
}
