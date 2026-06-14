import 'package:get_it/get_it.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../data/datasources/scores_remote_datasource.dart';
import '../data/repositories/scores_repository_impl.dart';
import '../domain/repositories/scores_repository.dart';
import '../domain/usecases/get_scores_usecase.dart';
import '../domain/usecases/recompute_score_usecase.dart';
import '../presentation/bloc/wellbeing360_bloc.dart';

void setupWellbeing360Module(GetIt sl) {
  sl.registerLazySingleton<ScoresRemoteDataSource>(
    () => ScoresRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<ScoresRepository>(
    () => ScoresRepositoryImpl(sl<ScoresRemoteDataSource>()),
  );

  sl.registerFactory<GetScoresUseCase>(
    () => GetScoresUseCase(sl<ScoresRepository>()),
  );
  sl.registerFactory<RecomputeScoreUseCase>(
    () => RecomputeScoreUseCase(sl<ScoresRepository>()),
  );

  sl.registerFactory<Wellbeing360Bloc>(
    () => Wellbeing360Bloc(
      getScoresUseCase: sl<GetScoresUseCase>(),
      recomputeScoreUseCase: sl<RecomputeScoreUseCase>(),
      session: sl<AuthSession>(),
    ),
  );
}
