import 'package:aura/core/database/app_database.dart';
import 'package:aura/core/network/api_client.dart';
import 'package:get_it/get_it.dart';
import '../data/datasources/conversation_remote_datasource.dart';
import '../data/datasources/conversation_session_datasource.dart';
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

  sl.registerLazySingleton<ConversationSessionDataSource>(
    () => ConversationSessionDataSourceImpl(),
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
    ),
  );
}
