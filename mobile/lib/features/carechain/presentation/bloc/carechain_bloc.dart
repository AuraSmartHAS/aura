import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/failure_messages.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/features/wellbeing360/domain/entities/score.dart';
import 'package:aura/features/wellbeing360/domain/usecases/recompute_score_usecase.dart';
import '../../domain/entities/recommendation.dart';
import '../../domain/usecases/approve_recommendation_usecase.dart';
import '../../domain/usecases/create_recommendation_usecase.dart';

part 'carechain_event.dart';
part 'carechain_state.dart';

class CareChainBloc extends Bloc<CareChainEvent, CareChainState> {
  CareChainBloc({
    required RecomputeScoreUseCase recomputeScoreUseCase,
    required CreateRecommendationUseCase createRecommendationUseCase,
    required ApproveRecommendationUseCase approveRecommendationUseCase,
    required AuthSession session,
  })  : _recomputeScoreUseCase = recomputeScoreUseCase,
        _createRecommendationUseCase = createRecommendationUseCase,
        _approveRecommendationUseCase = approveRecommendationUseCase,
        _session = session,
        super(const CareChainState.loading()) {
    on<LoadRecommendationEvent>(_onLoad);
    on<ApproveRecommendationEvent>(_onApprove);
  }

  final RecomputeScoreUseCase _recomputeScoreUseCase;
  final CreateRecommendationUseCase _createRecommendationUseCase;
  final ApproveRecommendationUseCase _approveRecommendationUseCase;
  final AuthSession _session;

  Future<void> _onLoad(
    LoadRecommendationEvent event,
    Emitter<CareChainState> emit,
  ) async {
    final homeId = _session.homeId;
    if (homeId == null) {
      emit(const CareChainState.error('Nenhuma casa cadastrada.'));
      return;
    }
    emit(const CareChainState.loading());

    // 1. Highest-risk score (recompute all dimensions).
    final scoreResult = await _recomputeScoreUseCase(homeId);
    if (scoreResult is Failure<Score>) {
      emit(CareChainState.error(AppFailureMessage.resolve(scoreResult.failure)));
      return;
    }
    final score = (scoreResult as Success<Score>).data;

    // 2. Explainable recommendation for that score.
    final recoResult = await _createRecommendationUseCase(
      homeId: homeId,
      scoreId: score.scoreId,
      level: score.level,
    );
    switch (recoResult) {
      case Success(:final data):
        emit(CareChainState.ready(data));
      case Failure(:final failure):
        // NO_PRODUCT means there is nothing to recommend — a good outcome.
        if (failure is AppFailure &&
            failure.maybeWhen(
              businessRule: (code, _) => code == 'NO_PRODUCT',
              notFound: (_) => true,
              orElse: () => false,
            )) {
          emit(const CareChainState.empty());
        } else {
          emit(CareChainState.error(AppFailureMessage.resolve(failure)));
        }
    }
  }

  Future<void> _onApprove(
    ApproveRecommendationEvent event,
    Emitter<CareChainState> emit,
  ) async {
    emit(state.copyWith(isApproving: true, clearError: true));
    final result = await _approveRecommendationUseCase(event.recommendationId);
    switch (result) {
      case Success(:final data):
        emit(state.copyWith(isApproving: false, approvedOrderId: data));
      case Failure(:final failure):
        emit(state.copyWith(
          isApproving: false,
          errorMessage: AppFailureMessage.resolve(failure),
        ));
    }
  }
}
