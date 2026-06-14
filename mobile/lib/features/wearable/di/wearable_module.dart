import 'package:get_it/get_it.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../data/datasources/signals_remote_datasource.dart';
import '../data/datasources/wearable_local_datasource.dart';
import '../data/repositories/wearable_repository_impl.dart';
import '../domain/repositories/wearable_repository.dart';
import '../domain/usecases/sync_wearable_usecase.dart';
import '../presentation/bloc/wearable_bloc.dart';

void setupWearableModule(GetIt sl) {
  sl.registerLazySingleton<WearableLocalDataSource>(
    () => WearableLocalDataSourceImpl(),
  );
  sl.registerLazySingleton<SignalsRemoteDataSource>(
    () => SignalsRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<WearableRepository>(
    () => WearableRepositoryImpl(
      sl<WearableLocalDataSource>(),
      sl<SignalsRemoteDataSource>(),
      sl<AuthSession>(),
    ),
  );

  sl.registerFactory<SyncWearableUseCase>(
    () => SyncWearableUseCase(sl<WearableRepository>()),
  );

  sl.registerFactory<WearableBloc>(
    () => WearableBloc(sl<SyncWearableUseCase>()),
  );
}
