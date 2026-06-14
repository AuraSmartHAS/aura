import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:aura/core/errors/failure_messages.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/auth_session.dart';
import '../../domain/entities/medication.dart';
import '../../domain/usecases/delete_medication_usecase.dart';
import '../../domain/usecases/get_medications_usecase.dart';
import '../../domain/usecases/save_medication_usecase.dart';

part 'medication_event.dart';
part 'medication_state.dart';

class MedicationBloc extends Bloc<MedicationEvent, MedicationState> {
  MedicationBloc({
    required GetMedicationsUseCase getMedicationsUseCase,
    required SaveMedicationUseCase saveMedicationUseCase,
    required DeleteMedicationUseCase deleteMedicationUseCase,
    required AuthSession session,
  })  : _getMedicationsUseCase = getMedicationsUseCase,
        _saveMedicationUseCase = saveMedicationUseCase,
        _deleteMedicationUseCase = deleteMedicationUseCase,
        _session = session,
        super(const MedicationState.loading()) {
    on<LoadMedicationsEvent>(_onLoad);
    on<SaveMedicationEvent>(_onSave);
    on<DeleteMedicationEvent>(_onDelete);
  }

  final GetMedicationsUseCase _getMedicationsUseCase;
  final SaveMedicationUseCase _saveMedicationUseCase;
  final DeleteMedicationUseCase _deleteMedicationUseCase;
  final AuthSession _session;

  Future<void> _onLoad(
    LoadMedicationsEvent event,
    Emitter<MedicationState> emit,
  ) async {
    final homeId = _session.homeId;
    if (homeId == null) {
      emit(const MedicationState.error('Nenhuma casa cadastrada.'));
      return;
    }
    emit(const MedicationState.loading());
    final result = await _getMedicationsUseCase(homeId);
    switch (result) {
      case Success(:final data):
        emit(MedicationState.ready(data));
      case Failure(:final failure):
        emit(MedicationState.error(AppFailureMessage.resolve(failure)));
    }
  }

  Future<void> _onSave(
    SaveMedicationEvent event,
    Emitter<MedicationState> emit,
  ) async {
    final homeId = _session.homeId;
    if (homeId == null) return;
    final medication = Medication(
      id: event.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      homeId: homeId,
      name: event.name,
      dosage: event.dosage,
      schedule: event.schedule,
      notes: event.notes,
    );
    await _saveMedicationUseCase(medication);
    add(const LoadMedicationsEvent());
  }

  Future<void> _onDelete(
    DeleteMedicationEvent event,
    Emitter<MedicationState> emit,
  ) async {
    await _deleteMedicationUseCase(event.id);
    add(const LoadMedicationsEvent());
  }
}
