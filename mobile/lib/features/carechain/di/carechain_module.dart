import 'package:get_it/get_it.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../wellbeing360/domain/usecases/recompute_score_usecase.dart';
import '../data/datasources/carechain_remote_datasource.dart';
import '../data/repositories/carechain_repository_impl.dart';
import '../domain/repositories/carechain_repository.dart';
import '../domain/usecases/approve_recommendation_usecase.dart';
import '../domain/usecases/create_recommendation_usecase.dart';
import '../presentation/bloc/carechain_bloc.dart';

void setupCareChainModule(GetIt sl) {
  sl.registerLazySingleton<CareChainRemoteDataSource>(
    () => CareChainRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<CareChainRepository>(
    () => CareChainRepositoryImpl(sl<CareChainRemoteDataSource>()),
  );

  sl.registerFactory<CreateRecommendationUseCase>(
    () => CreateRecommendationUseCase(sl<CareChainRepository>()),
  );
  sl.registerFactory<ApproveRecommendationUseCase>(
    () => ApproveRecommendationUseCase(sl<CareChainRepository>()),
  );

  sl.registerFactory<CareChainBloc>(
    () => CareChainBloc(
      recomputeScoreUseCase: sl<RecomputeScoreUseCase>(),
      createRecommendationUseCase: sl<CreateRecommendationUseCase>(),
      approveRecommendationUseCase: sl<ApproveRecommendationUseCase>(),
      session: sl<AuthSession>(),
    ),
  );
}
