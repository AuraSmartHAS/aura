part of 'medication_bloc.dart';

abstract class MedicationEvent extends Equatable {
  const MedicationEvent();

  @override
  List<Object?> get props => [];
}

class LoadMedicationsEvent extends MedicationEvent {
  const LoadMedicationsEvent();
}

class SaveMedicationEvent extends MedicationEvent {
  const SaveMedicationEvent({
    this.id,
    required this.name,
    this.dosage,
    this.times = const [],
    this.notes,
    this.stockDoses,
  });

  /// Null for a new entry; set when editing.
  final String? id;
  final String name;
  final String? dosage;

  /// Already validated `HH:mm` times.
  final List<String> times;
  final String? notes;
  final int? stockDoses;

  @override
  List<Object?> get props => [id, name, dosage, times, notes, stockDoses];
}

class DeleteMedicationEvent extends MedicationEvent {
  const DeleteMedicationEvent(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// "Tomei" ([taken] true) / "Não tomei" ([taken] false) for one medication.
class ConfirmDoseEvent extends MedicationEvent {
  const ConfirmDoseEvent(this.id, {required this.taken});

  final String id;
  final bool taken;

  @override
  List<Object?> get props => [id, taken];
}
