import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:aura/core/errors/failure_messages.dart';
import 'package:aura/core/errors/result.dart';
import '../../domain/entities/home.dart';
import '../../domain/usecases/create_home_usecase.dart';
import '../../domain/usecases/update_checklist_usecase.dart';

part 'home_setup_event.dart';
part 'home_setup_state.dart';

class HomeSetupBloc extends Bloc<HomeSetupEvent, HomeSetupState> {
  HomeSetupBloc({
    required CreateHomeUseCase createHomeUseCase,
    required UpdateChecklistUseCase updateChecklistUseCase,
  })  : _createHomeUseCase = createHomeUseCase,
        _updateChecklistUseCase = updateChecklistUseCase,
        super(HomeSetupState.initial()) {
    on<SubmitHomeFormEvent>(_onSubmitForm);
    on<ToggleChecklistItemEvent>(_onToggleItem);
    on<SubmitChecklistEvent>(_onSubmitChecklist);
  }

  final CreateHomeUseCase _createHomeUseCase;
  final UpdateChecklistUseCase _updateChecklistUseCase;

  Future<void> _onSubmitForm(
    SubmitHomeFormEvent event,
    Emitter<HomeSetupState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    final result = await _createHomeUseCase(
      patientName: event.patientName,
      cep: event.cep,
      birthDate: event.birthDate,
      label: event.label,
    );
    switch (result) {
      case Success(:final data):
        emit(state.copyWith(
          isLoading: false,
          step: SetupStep.checklist,
          home: data,
        ));
      case Failure(:final failure):
        emit(state.copyWith(
          isLoading: false,
          errorMessage: AppFailureMessage.resolve(failure),
        ));
    }
  }

  void _onToggleItem(
    ToggleChecklistItemEvent event,
    Emitter<HomeSetupState> emit,
  ) {
    final updated = Map<String, bool>.from(state.checklist)
      ..[event.key] = event.value;
    emit(state.copyWith(checklist: updated));
  }

  Future<void> _onSubmitChecklist(
    SubmitChecklistEvent event,
    Emitter<HomeSetupState> emit,
  ) async {
    final home = state.home;
    if (home == null) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    final result = await _updateChecklistUseCase(home.id, state.checklist);
    switch (result) {
      case Success():
        emit(state.copyWith(isLoading: false, step: SetupStep.done));
      case Failure(:final failure):
        emit(state.copyWith(
          isLoading: false,
          errorMessage: AppFailureMessage.resolve(failure),
        ));
    }
  }
}
