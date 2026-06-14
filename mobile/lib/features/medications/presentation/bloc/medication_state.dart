part of 'medication_bloc.dart';

enum MedicationStatus { loading, ready, error }

class MedicationState extends Equatable {
  const MedicationState({
    required this.status,
    this.medications = const [],
    this.errorMessage,
  });

  const MedicationState.loading()
      : status = MedicationStatus.loading,
        medications = const [],
        errorMessage = null;

  const MedicationState.ready(this.medications)
      : status = MedicationStatus.ready,
        errorMessage = null;

  const MedicationState.error(this.errorMessage)
      : status = MedicationStatus.error,
        medications = const [];

  final MedicationStatus status;
  final List<Medication> medications;
  final String? errorMessage;

  @override
  List<Object?> get props =>
      [status, medications.map((m) => m.id).toList(), errorMessage];
}
