import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:aura/core/errors/failure_messages.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/auth_session.dart';
import '../../domain/entities/medication.dart';
import '../../domain/usecases/confirm_dose_usecase.dart';
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
    required ConfirmDoseUseCase confirmDoseUseCase,
    required AuthSession session,
  })  : _getMedicationsUseCase = getMedicationsUseCase,
        _saveMedicationUseCase = saveMedicationUseCase,
        _deleteMedicationUseCase = deleteMedicationUseCase,
        _confirmDoseUseCase = confirmDoseUseCase,
        _session = session,
        super(const MedicationState.loading()) {
    on<LoadMedicationsEvent>(_onLoad);
    on<SaveMedicationEvent>(_onSave);
    on<DeleteMedicationEvent>(_onDelete);
    on<ConfirmDoseEvent>(_onConfirmDose);
  }

  final GetMedicationsUseCase _getMedicationsUseCase;
  final SaveMedicationUseCase _saveMedicationUseCase;
  final DeleteMedicationUseCase _deleteMedicationUseCase;
  final ConfirmDoseUseCase _confirmDoseUseCase;
  final AuthSession _session;

  int _feedbackSequence = 0;

  MedicationFeedback _feedback(String message, {bool isError = false}) =>
      MedicationFeedback(
        message,
        isError: isError,
        sequence: ++_feedbackSequence,
      );

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
    final input = MedicationInput(
      name: event.name,
      dosage: event.dosage,
      times: event.times,
      notes: event.notes,
      stockDoses: event.stockDoses,
    );
    final result = await _saveMedicationUseCase(homeId, input, id: event.id);
    switch (result) {
      case Success(:final data):
        if (state.status != MedicationStatus.ready) {
          add(const LoadMedicationsEvent());
          return;
        }
        // The server answers with the saved entity: no need to refetch.
        final meds = [
          for (final m in state.medications)
            if (m.id != data.id) m,
          data,
        ]..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        emit(state.copyWith(
          medications: meds,
          feedback: _feedback(
            event.id == null ? 'Medicamento cadastrado.' : 'Alterações salvas.',
          ),
        ));
      case Failure(:final failure):
        emit(state.copyWith(
          feedback: _feedback(
            'Não foi possível salvar: ${AppFailureMessage.resolve(failure)}',
            isError: true,
          ),
        ));
    }
  }

  Future<void> _onDelete(
    DeleteMedicationEvent event,
    Emitter<MedicationState> emit,
  ) async {
    final result = await _deleteMedicationUseCase(event.id);
    switch (result) {
      case Success():
        emit(state.copyWith(
          medications: [
            for (final m in state.medications)
              if (m.id != event.id) m,
          ],
          feedback: _feedback('Medicamento removido.'),
        ));
      case Failure(:final failure):
        emit(state.copyWith(
          feedback: _feedback(
            'Não foi possível remover: ${AppFailureMessage.resolve(failure)}',
            isError: true,
          ),
        ));
    }
  }

  Future<void> _onConfirmDose(
    ConfirmDoseEvent event,
    Emitter<MedicationState> emit,
  ) async {
    if (state.confirmingIds.contains(event.id)) return;
    emit(state.copyWith(confirmingIds: {...state.confirmingIds, event.id}));

    final result = await _confirmDoseUseCase(event.id, taken: event.taken);
    final remaining = {...state.confirmingIds}..remove(event.id);
    switch (result) {
      case Success(:final data):
        emit(state.copyWith(
          confirmingIds: remaining,
          medications: [
            for (final m in state.medications)
              m.id == event.id ? m.copyWith(stockDoses: data.stockDoses) : m,
          ],
          feedback: _feedback(_confirmationMessage(data)),
        ));
      case Failure(:final failure):
        emit(state.copyWith(
          confirmingIds: remaining,
          feedback: _feedback(
            'Não foi possível registrar a dose: '
            '${AppFailureMessage.resolve(failure)}',
            isError: true,
          ),
        ));
    }
  }

  static String _confirmationMessage(DoseConfirmation c) {
    final head = c.taken ? 'Dose registrada.' : 'Registrado: dose não tomada.';
    final stock = c.stockDoses;
    if (stock == null) return head;
    return '$head ${stockLabel(stock)} em estoque.';
  }

  /// "1 dose" / "12 doses" — shared with the card.
  static String stockLabel(int stock) => stock == 1 ? '1 dose' : '$stock doses';
}
