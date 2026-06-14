import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:aura/core/errors/failure_messages.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/features/home_setup/domain/entities/home.dart';
import 'package:aura/features/home_setup/domain/usecases/get_home_usecase.dart';
import 'package:aura/features/wellbeing360/domain/entities/score.dart';
import 'package:aura/features/wellbeing360/domain/usecases/get_scores_usecase.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

/// Aggregates the caregiver "status of the day": home detail + highest risk.
/// Consumes use cases exported by `home_setup` and `wellbeing360` (no direct
/// data coupling), per the cross-feature rule.
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({
    required GetHomeUseCase getHomeUseCase,
    required GetScoresUseCase getScoresUseCase,
    required AuthSession session,
  })  : _getHomeUseCase = getHomeUseCase,
        _getScoresUseCase = getScoresUseCase,
        _session = session,
        super(const DashboardState.loading()) {
    on<LoadDashboardEvent>(_onLoad);
  }

  final GetHomeUseCase _getHomeUseCase;
  final GetScoresUseCase _getScoresUseCase;
  final AuthSession _session;

  Future<void> _onLoad(
    LoadDashboardEvent event,
    Emitter<DashboardState> emit,
  ) async {
    final homeId = _session.homeId;
    if (homeId == null) {
      emit(const DashboardState.error('Nenhuma casa cadastrada.'));
      return;
    }
    emit(const DashboardState.loading());

    final homeResult = await _getHomeUseCase(homeId);
    if (homeResult is Failure<HomeDetail>) {
      emit(DashboardState.error(AppFailureMessage.resolve(homeResult.failure)));
      return;
    }
    final homeDetail = (homeResult as Success<HomeDetail>).data;

    // Scores are best-effort: a brand new home may have none yet.
    Score? topScore;
    final scoresResult = await _getScoresUseCase(homeId);
    if (scoresResult is Success<List<Score>>) {
      topScore = _highestRisk(scoresResult.data);
    }

    emit(DashboardState.ready(homeDetail: homeDetail, topScore: topScore));
  }

  Score? _highestRisk(List<Score> scores) {
    if (scores.isEmpty) return null;
    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores.first;
  }
}
