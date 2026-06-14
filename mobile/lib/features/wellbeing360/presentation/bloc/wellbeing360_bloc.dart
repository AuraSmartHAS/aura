import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:aura/core/errors/failure_messages.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/auth_session.dart';
import '../../domain/entities/score.dart';
import '../../domain/usecases/get_scores_usecase.dart';
import '../../domain/usecases/recompute_score_usecase.dart';

part 'wellbeing360_event.dart';
part 'wellbeing360_state.dart';

class Wellbeing360Bloc extends Bloc<Wellbeing360Event, Wellbeing360State> {
  Wellbeing360Bloc({
    required GetScoresUseCase getScoresUseCase,
    required RecomputeScoreUseCase recomputeScoreUseCase,
    required AuthSession session,
  })  : _getScoresUseCase = getScoresUseCase,
        _recomputeScoreUseCase = recomputeScoreUseCase,
        _session = session,
        super(const Wellbeing360State.loading()) {
    on<LoadScoresEvent>(_onLoad);
    on<RecomputeScoresEvent>(_onRecompute);
  }

  final GetScoresUseCase _getScoresUseCase;
  final RecomputeScoreUseCase _recomputeScoreUseCase;
  final AuthSession _session;

  Future<void> _onLoad(
    LoadScoresEvent event,
    Emitter<Wellbeing360State> emit,
  ) async {
    final homeId = _session.homeId;
    if (homeId == null) {
      emit(const Wellbeing360State.error('Nenhuma casa cadastrada.'));
      return;
    }
    emit(const Wellbeing360State.loading());
    final result = await _getScoresUseCase(homeId);
    switch (result) {
      case Success(:final data):
        emit(Wellbeing360State.ready(data));
      case Failure(:final failure):
        emit(Wellbeing360State.error(AppFailureMessage.resolve(failure)));
    }
  }

  Future<void> _onRecompute(
    RecomputeScoresEvent event,
    Emitter<Wellbeing360State> emit,
  ) async {
    final homeId = _session.homeId;
    if (homeId == null) return;
    emit(state.copyWith(isRecomputing: true));
    await _recomputeScoreUseCase(homeId, dimension: event.dimension);
    add(const LoadScoresEvent());
  }
}
