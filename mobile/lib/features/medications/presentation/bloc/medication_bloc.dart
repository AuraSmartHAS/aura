import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:aura/core/errors/failure_messages.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/features/caregiver_dashboard/domain/care_today_builder.dart';
import 'package:aura/features/caregiver_dashboard/domain/entities/care_signal.dart';
import 'package:aura/features/caregiver_dashboard/domain/entities/care_today.dart';
import 'package:aura/features/caregiver_dashboard/domain/usecases/care_feed_usecases.dart';
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
    GetCareSignalsUseCase? getCareSignalsUseCase,
    DateTime Function()? now,
  })  : _getCareSignalsUseCase = getCareSignalsUseCase,
        _now = now ?? DateTime.now,
        _getMedicationsUseCase = getMedicationsUseCase,
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
  final GetCareSignalsUseCase? _getCareSignalsUseCase;
  final DateTime Function() _now;

  /// A família lê a situação de hoje; quem confirma a dose é a paciente.
  bool get isCaregiver => _session.role != null && !_session.role!.isPatient;

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
        // A lista aparece já; o estado de hoje (da família) chega depois, sem
        // atrasar os remédios se os sinais demorarem.
        final wantsToday = isCaregiver && _getCareSignalsUseCase != null;
        emit(MedicationState.ready(
          data,
          todayStatus:
              wantsToday ? TodayStatus.loading : TodayStatus.notApplicable,
        ));
        if (wantsToday) {
          final today = await _today(homeId, data);
          if (isClosed) return;
          emit(state.copyWith(
            todayById: today ?? const {},
            todayStatus: today == null ? TodayStatus.failed : TodayStatus.loaded,
          ));
        }
      case Failure(:final failure):
        emit(MedicationState.error(AppFailureMessage.resolve(failure)));
    }
  }

  /// Situação de hoje de cada remédio, só para a família. `null` quando os sinais
  /// não carregaram: sem eles o estado de dose não existe (e "atrasada" calculada
  /// só pelo relógio seria falso) — a tela diz que não conseguiu carregar.
  Future<Map<String, MedicationToday>?> _today(
    String homeId,
    List<Medication> medications,
  ) async {
    final feed = _getCareSignalsUseCase!;
    final n = _now();
    final signals = await feed(homeId,
        since: DateTime(n.year, n.month, n.day), type: 'adherence');
    if (signals is! Success<List<CareSignal>>) return null;
    return {
      for (final item in CareTodayBuilder.medicationsToday(
          medications, signals.data, n))
        item.medication.id: item,
    };
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
