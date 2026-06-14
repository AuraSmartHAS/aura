import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:aura/core/errors/failure_messages.dart';
import 'package:aura/core/errors/result.dart';
import '../../domain/usecases/accept_consent_usecase.dart';

part 'consent_event.dart';
part 'consent_state.dart';

class ConsentBloc extends Bloc<ConsentEvent, ConsentState> {
  ConsentBloc(this._acceptConsentUseCase) : super(const ConsentInitial()) {
    on<AcceptConsentEvent>(_onAccept);
  }

  final AcceptConsentUseCase _acceptConsentUseCase;

  Future<void> _onAccept(
    AcceptConsentEvent event,
    Emitter<ConsentState> emit,
  ) async {
    emit(const ConsentLoading());
    final result = await _acceptConsentUseCase();
    switch (result) {
      case Success():
        emit(const ConsentAccepted());
      case Failure(:final failure):
        emit(ConsentError(AppFailureMessage.resolve(failure)));
    }
  }
}
