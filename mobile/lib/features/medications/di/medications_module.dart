import 'package:get_it/get_it.dart';
import '../../../core/database/app_database.dart';
import '../../../core/session/auth_session.dart';
import '../data/datasources/medication_local_datasource.dart';
import '../data/repositories/medication_repository_impl.dart';
import '../domain/repositories/medication_repository.dart';
import '../domain/usecases/delete_medication_usecase.dart';
import '../domain/usecases/get_medications_usecase.dart';
import '../domain/usecases/save_medication_usecase.dart';
import '../presentation/bloc/medication_bloc.dart';

void setupMedicationsModule(GetIt sl) {
  // AppDatabase is registered by the home module.
  sl.registerLazySingleton<MedicationLocalDataSource>(
    () => MedicationLocalDataSourceImpl(sl<AppDatabase>()),
  );

  sl.registerLazySingleton<MedicationRepository>(
    () => MedicationRepositoryImpl(sl<MedicationLocalDataSource>()),
  );

  sl.registerFactory<GetMedicationsUseCase>(
    () => GetMedicationsUseCase(sl<MedicationRepository>()),
  );
  sl.registerFactory<SaveMedicationUseCase>(
    () => SaveMedicationUseCase(sl<MedicationRepository>()),
  );
  sl.registerFactory<DeleteMedicationUseCase>(
    () => DeleteMedicationUseCase(sl<MedicationRepository>()),
  );

  sl.registerFactory<MedicationBloc>(
    () => MedicationBloc(
      getMedicationsUseCase: sl<GetMedicationsUseCase>(),
      saveMedicationUseCase: sl<SaveMedicationUseCase>(),
      deleteMedicationUseCase: sl<DeleteMedicationUseCase>(),
      session: sl<AuthSession>(),
    ),
  );
}
