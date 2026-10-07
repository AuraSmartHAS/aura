part of 'medication_bloc.dart';

enum MedicationStatus { loading, ready, error }

/// One-shot message for a SnackBar. [sequence] makes two equal messages in a
/// row still count as distinct states.
class MedicationFeedback extends Equatable {
  const MedicationFeedback(this.message,
      {required this.sequence, this.isError = false});

  final String message;
  final bool isError;
  final int sequence;

  @override
  List<Object?> get props => [message, isError, sequence];
}

class MedicationState extends Equatable {
  const MedicationState({
    required this.status,
    this.medications = const [],
    this.errorMessage,
    this.confirmingIds = const {},
    this.feedback,
  });

  const MedicationState.loading()
      : status = MedicationStatus.loading,
        medications = const [],
        errorMessage = null,
        confirmingIds = const {},
        feedback = null;

  const MedicationState.ready(this.medications)
      : status = MedicationStatus.ready,
        errorMessage = null,
        confirmingIds = const {},
        feedback = null;

  const MedicationState.error(this.errorMessage)
      : status = MedicationStatus.error,
        medications = const [],
        confirmingIds = const {},
        feedback = null;

  final MedicationStatus status;
  final List<Medication> medications;
  final String? errorMessage;

  /// Medications with a dose confirmation in flight (buttons disabled).
  final Set<String> confirmingIds;
  final MedicationFeedback? feedback;

  MedicationState copyWith({
    List<Medication>? medications,
    Set<String>? confirmingIds,
    MedicationFeedback? feedback,
  }) {
    return MedicationState(
      status: status,
      medications: medications ?? this.medications,
      errorMessage: errorMessage,
      confirmingIds: confirmingIds ?? this.confirmingIds,
      feedback: feedback ?? this.feedback,
    );
  }

  @override
  List<Object?> get props =>
      [status, medications, errorMessage, confirmingIds, feedback];
}
