import 'package:get_it/get_it.dart';

import 'package:aura/core/config/app_config.dart';
import 'package:aura/core/network/api_client.dart';
import 'package:aura/core/platform/phone_dialer.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';

import '../data/datasources/emergency_remote_datasource.dart';
import '../data/repositories/emergency_repository_impl.dart';
import '../domain/repositories/emergency_repository.dart';
import '../domain/usecases/cancel_emergency_usecase.dart';
import '../domain/usecases/get_emergency_status_usecase.dart';
import '../domain/usecases/trigger_emergency_usecase.dart';
import '../presentation/bloc/sos_bloc.dart';

void setupSosModule(GetIt sl) {
  // Datasources
  sl.registerLazySingleton<EmergencyRemoteDataSource>(
    () => EmergencyRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<PhoneDialer>(() => const UrlLauncherPhoneDialer());

  // Repository
  sl.registerLazySingleton<EmergencyRepository>(
    () => EmergencyRepositoryImpl(
      sl<EmergencyRemoteDataSource>(),
      // A sessão primeiro, porque é a casa em uso agora; o armazenamento
      // depois, porque é o que sobra quando a sessão morre — e é justamente aí
      // que o socorro não pode parar de funcionar (regra 3).
      pairedHomeId: () async =>
          sl<AuthSession>().homeId ?? await sl<TokenStore>().pairedHomeId,
    ),
  );

  // Use cases
  sl.registerFactory<TriggerEmergencyUseCase>(
    () => TriggerEmergencyUseCase(sl<EmergencyRepository>()),
  );
  sl.registerFactory<CancelEmergencyUseCase>(
    () => CancelEmergencyUseCase(sl<EmergencyRepository>()),
  );
  sl.registerFactory<GetEmergencyStatusUseCase>(
    () => GetEmergencyStatusUseCase(sl<EmergencyRepository>()),
  );

  // BLoC — um por pedido de ajuda: nasce no toque, morre quando a folha fecha.
  sl.registerFactory<SosBloc>(
    () => SosBloc(
      triggerEmergencyUseCase: sl<TriggerEmergencyUseCase>(),
      cancelEmergencyUseCase: sl<CancelEmergencyUseCase>(),
      getEmergencyStatusUseCase: sl<GetEmergencyStatusUseCase>(),
      phoneDialer: sl<PhoneDialer>(),
      emergencyPhone: AppConfig.sosEmergencyPhone,
      contactPhone: AppConfig.sosContactPhone,
    ),
  );
}
