import 'package:get_it/get_it.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/session/token_store.dart';
import '../data/datasources/consent_remote_datasource.dart';
import '../data/repositories/consent_repository_impl.dart';
import '../domain/repositories/consent_repository.dart';
import '../domain/usecases/accept_consent_usecase.dart';
import '../presentation/bloc/consent_bloc.dart';

void setupConsentModule(GetIt sl) {
  sl.registerLazySingleton<ConsentRemoteDataSource>(
    () => ConsentRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<ConsentRepository>(
    () => ConsentRepositoryImpl(
      sl<ConsentRemoteDataSource>(),
      sl<TokenStore>(),
      sl<AuthSession>(),
    ),
  );

  sl.registerFactory<AcceptConsentUseCase>(
    () => AcceptConsentUseCase(sl<ConsentRepository>()),
  );

  sl.registerFactory<ConsentBloc>(
    () => ConsentBloc(sl<AcceptConsentUseCase>()),
  );
}
