import 'package:get_it/get_it.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/session/token_store.dart';
import '../data/datasources/home_remote_datasource.dart';
import '../data/repositories/home_repository_impl.dart';
import '../domain/repositories/home_repository.dart';
import '../domain/usecases/create_home_usecase.dart';
import '../domain/usecases/get_home_usecase.dart';
import '../domain/usecases/update_checklist_usecase.dart';
import '../presentation/bloc/home_setup_bloc.dart';

void setupHomeSetupModule(GetIt sl) {
  sl.registerLazySingleton<HomeRemoteDataSource>(
    () => HomeRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(
      sl<HomeRemoteDataSource>(),
      sl<TokenStore>(),
      sl<AuthSession>(),
    ),
  );

  sl.registerFactory<CreateHomeUseCase>(
    () => CreateHomeUseCase(sl<HomeRepository>()),
  );
  sl.registerFactory<GetHomeUseCase>(
    () => GetHomeUseCase(sl<HomeRepository>()),
  );
  sl.registerFactory<UpdateChecklistUseCase>(
    () => UpdateChecklistUseCase(sl<HomeRepository>()),
  );

  sl.registerFactory<HomeSetupBloc>(
    () => HomeSetupBloc(
      createHomeUseCase: sl<CreateHomeUseCase>(),
      updateChecklistUseCase: sl<UpdateChecklistUseCase>(),
    ),
  );
}
