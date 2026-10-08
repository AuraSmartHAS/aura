part of 'medication_bloc.dart';

enum MedicationStatus { loading, ready, error }

/// O estado de hoje dos remédios (só para a família): ainda buscando, pronto, ou
/// não deu para carregar — que é diferente de "sem informação".
enum TodayStatus { notApplicable, loading, loaded, failed }

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
    this.todayById = const {},
    this.todayStatus = TodayStatus.notApplicable,
  });

  const MedicationState.loading()
      : status = MedicationStatus.loading,
        medications = const [],
        errorMessage = null,
        confirmingIds = const {},
        feedback = null,
        todayById = const {},
        todayStatus = TodayStatus.notApplicable;

  const MedicationState.ready(this.medications,
      {this.todayById = const {},
      this.todayStatus = TodayStatus.notApplicable})
      : status = MedicationStatus.ready,
        errorMessage = null,
        confirmingIds = const {},
        feedback = null;

  const MedicationState.error(this.errorMessage)
      : status = MedicationStatus.error,
        medications = const [],
        confirmingIds = const {},
        feedback = null,
        todayById = const {},
        todayStatus = TodayStatus.notApplicable;

  final MedicationStatus status;
  final List<Medication> medications;
  final String? errorMessage;

  /// Medications with a dose confirmation in flight (buttons disabled).
  final Set<String> confirmingIds;
  final MedicationFeedback? feedback;

  /// Como cada remédio está hoje, por id. Só a família recebe (a paciente
  /// confirma a dose; a família lê o resultado).
  final Map<String, MedicationToday> todayById;
  final TodayStatus todayStatus;

  MedicationState copyWith({
    List<Medication>? medications,
    Set<String>? confirmingIds,
    MedicationFeedback? feedback,
    Map<String, MedicationToday>? todayById,
    TodayStatus? todayStatus,
  }) {
    return MedicationState(
      status: status,
      medications: medications ?? this.medications,
      errorMessage: errorMessage,
      confirmingIds: confirmingIds ?? this.confirmingIds,
      feedback: feedback ?? this.feedback,
      todayById: todayById ?? this.todayById,
      todayStatus: todayStatus ?? this.todayStatus,
    );
  }

  @override
  List<Object?> get props =>
      [
        status,
        medications,
        errorMessage,
        confirmingIds,
        feedback,
        todayById,
        todayStatus,
      ];
}
