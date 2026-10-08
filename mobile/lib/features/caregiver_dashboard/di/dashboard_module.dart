import 'package:get_it/get_it.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../home_setup/domain/usecases/get_home_usecase.dart';
import '../../medications/domain/usecases/get_medications_usecase.dart';
import '../../wellbeing360/domain/usecases/get_scores_usecase.dart';
import '../data/datasources/care_feed_remote_datasource.dart';
import '../data/repositories/care_feed_repository_impl.dart';
import '../domain/repositories/care_feed_repository.dart';
import '../domain/usecases/care_feed_usecases.dart';
import '../presentation/bloc/dashboard_bloc.dart';

void setupDashboardModule(GetIt sl) {
  sl.registerLazySingleton<CareFeedRemoteDataSource>(
    () => CareFeedRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<CareFeedRepository>(
    () => CareFeedRepositoryImpl(sl<CareFeedRemoteDataSource>()),
  );
  sl.registerFactory<GetCareSignalsUseCase>(
    () => GetCareSignalsUseCase(sl<CareFeedRepository>()),
  );
  sl.registerFactory<GetActiveEmergencyUseCase>(
    () => GetActiveEmergencyUseCase(sl<CareFeedRepository>()),
  );
  sl.registerFactory<GetEmergencyOutcomeUseCase>(
    () => GetEmergencyOutcomeUseCase(sl<CareFeedRepository>()),
  );
  sl.registerFactory<AcknowledgeEmergencyUseCase>(
    () => AcknowledgeEmergencyUseCase(sl<CareFeedRepository>()),
  );

  // Reuses use cases registered by home_setup, wellbeing360 and medications.
  sl.registerFactory<DashboardBloc>(
    () => DashboardBloc(
      getHomeUseCase: sl<GetHomeUseCase>(),
      getScoresUseCase: sl<GetScoresUseCase>(),
      getMedicationsUseCase: sl<GetMedicationsUseCase>(),
      getCareSignalsUseCase: sl<GetCareSignalsUseCase>(),
      getActiveEmergencyUseCase: sl<GetActiveEmergencyUseCase>(),
      getEmergencyOutcomeUseCase: sl<GetEmergencyOutcomeUseCase>(),
      acknowledgeEmergencyUseCase: sl<AcknowledgeEmergencyUseCase>(),
      session: sl<AuthSession>(),
    ),
  );
}
