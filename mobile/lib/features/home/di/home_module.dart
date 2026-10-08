import 'package:aura/core/database/app_database.dart';
import 'package:aura/core/network/api_client.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/datasources/conversation_remote_datasource.dart';
import '../data/datasources/conversation_session_datasource.dart';
import '../data/datasources/symptom_remote_datasource.dart';
import '../data/repositories/symptom_repository_impl.dart';
import '../data/voice_tools/voice_client_tools.dart';
import '../data/voice_tools/voice_sos_gateway.dart';
import '../domain/repositories/symptom_repository.dart';
import '../domain/usecases/register_symptom_usecase.dart';
import 'package:aura/features/medications/domain/usecases/confirm_dose_usecase.dart';
import 'package:aura/features/medications/domain/usecases/get_medications_usecase.dart';
import 'package:aura/features/sos/domain/usecases/trigger_emergency_usecase.dart';
import '../data/repositories/conversation_repository_impl.dart';
import '../domain/repositories/conversation_repository.dart';
import '../domain/usecases/fetch_conversation_token_usecase.dart';
import '../domain/usecases/send_text_message_usecase.dart';
import '../domain/usecases/start_conversation_usecase.dart';
import '../domain/usecases/stop_conversation_usecase.dart';
import '../domain/usecases/toggle_mute_usecase.dart';
import '../presentation/bloc/home_bloc.dart';

void setupHomeModule(GetIt sl) {
  // Database
  sl.registerSingleton<AppDatabase>(AppDatabase());

  // Datasources
  sl.registerLazySingleton<ConversationRemoteDataSource>(
    () => ConversationRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<SymptomRemoteDataSource>(
    () => SymptomRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<SymptomRepository>(
    () => SymptomRepositoryImpl(sl<SymptomRemoteDataSource>()),
  );

  sl.registerFactory<RegisterSymptomUseCase>(
    () => RegisterSymptomUseCase(sl<SymptomRepository>()),
  );

  sl.registerLazySingleton<VoiceSosGateway>(
    () => VoiceSosGateway(),
    dispose: (gateway) => gateway.dispose(),
  );

  // As client tools resolvem as dependências por get_it só quando a sessão é
  // criada, então a ordem em que os módulos são registrados não importa.
  sl.registerLazySingleton<ConversationSessionDataSource>(
    () => ConversationSessionDataSourceImpl(
      clientTools: buildVoiceClientTools(
        registerSymptom: sl<RegisterSymptomUseCase>(),
        getMedications: sl<GetMedicationsUseCase>(),
        confirmDose: sl<ConfirmDoseUseCase>(),
        triggerEmergency: sl<TriggerEmergencyUseCase>(),
        session: sl<AuthSession>(),
        sosGateway: sl<VoiceSosGateway>(),
      ),
      // `name` é a variável dinâmica cadastrada no agente do ElevenLabs.
      dynamicVariables: () => {
        'name': sl<AuthSession>().userFirstName ?? 'você',
      },
    ),
  );

  // Repository
  sl.registerLazySingleton<ConversationRepository>(
    () => ConversationRepositoryImpl(
      sl<ConversationRemoteDataSource>(),
      sl<ConversationSessionDataSource>(),
    ),
  );

  // Use cases
  sl.registerFactory<FetchConversationTokenUseCase>(
    () => FetchConversationTokenUseCase(sl<ConversationRepository>()),
  );

  sl.registerFactory<StartConversationUseCase>(
    () => StartConversationUseCase(sl<ConversationRepository>()),
  );

  sl.registerFactory<StopConversationUseCase>(
    () => StopConversationUseCase(sl<ConversationRepository>()),
  );

  sl.registerFactory<SendTextMessageUseCase>(
    () => SendTextMessageUseCase(sl<ConversationRepository>()),
  );

  sl.registerFactory<ToggleMuteUseCase>(
    () => ToggleMuteUseCase(sl<ConversationRepository>()),
  );

  // BLoC
  sl.registerFactory<HomeBloc>(
    () => HomeBloc(
      fetchTokenUseCase: sl<FetchConversationTokenUseCase>(),
      startConversationUseCase: sl<StartConversationUseCase>(),
      stopConversationUseCase: sl<StopConversationUseCase>(),
      sendTextMessageUseCase: sl<SendTextMessageUseCase>(),
      toggleMuteUseCase: sl<ToggleMuteUseCase>(),
      conversationRepository: sl<ConversationRepository>(),
      userFirstName: sl<AuthSession>().userFirstName,
      requestMicPermission: () => Permission.microphone.request(),
      greetingDismissedBefore: () => sl<AuthSession>().patientGreetingDismissed,
      onGreetingDismissed: () => sl<AuthSession>().dismissPatientGreeting(),
    ),
  );
}
