import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:aura/core/errors/failure_messages.dart';
import 'package:aura/core/errors/result.dart';
import '../../domain/entities/vitals.dart';
import '../../domain/usecases/sync_wearable_usecase.dart';

part 'wearable_event.dart';
part 'wearable_state.dart';

class WearableBloc extends Bloc<WearableEvent, WearableState> {
  WearableBloc(this._syncWearableUseCase)
      : super(const WearableState.initial()) {
    on<ConnectWearableEvent>(_onConnect);
  }

  final SyncWearableUseCase _syncWearableUseCase;

  Future<void> _onConnect(
    ConnectWearableEvent event,
    Emitter<WearableState> emit,
  ) async {
    emit(const WearableState.loading());
    final result = await _syncWearableUseCase();
    switch (result) {
      case Success(:final data):
        emit(WearableState.ready(data));
      case Failure(:final failure):
        emit(WearableState.error(AppFailureMessage.resolve(failure)));
    }
  }
}
