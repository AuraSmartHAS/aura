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
    this.schedule,
    this.notes,
  });

  /// Null for a new entry; set when editing.
  final String? id;
  final String name;
  final String? dosage;
  final String? schedule;
  final String? notes;

  @override
  List<Object?> get props => [id, name, dosage, schedule, notes];
}

class DeleteMedicationEvent extends MedicationEvent {
  const DeleteMedicationEvent(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}
