import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import '../data/datasources/auth_remote_datasource.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/login_usecase.dart';
import '../domain/usecases/logout_usecase.dart';
import '../domain/usecases/signup_usecase.dart';
import '../presentation/bloc/auth_bloc.dart';

void setupAuthModule(GetIt sl) {
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(FirebaseAuth.instance),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl<AuthRemoteDataSource>()),
  );

  sl.registerFactory<LoginUseCase>(
    () => LoginUseCase(sl<AuthRepository>()),
  );

  sl.registerFactory<SignupUseCase>(
    () => SignupUseCase(sl<AuthRepository>()),
  );

  sl.registerFactory<LogoutUseCase>(
    () => LogoutUseCase(sl<AuthRepository>()),
  );

  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      loginUseCase: sl<LoginUseCase>(),
      signupUseCase: sl<SignupUseCase>(),
      logoutUseCase: sl<LogoutUseCase>(),
    ),
  );
}
