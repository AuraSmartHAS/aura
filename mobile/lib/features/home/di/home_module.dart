import 'package:aura/core/database/app_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/datasources/conversation_remote_datasource.dart';
import '../data/datasources/conversation_session_datasource.dart';
import '../data/repositories/conversation_repository_impl.dart';
import '../domain/repositories/conversation_repository.dart';
import '../domain/usecases/fetch_conversation_token_usecase.dart';
import '../domain/usecases/start_conversation_usecase.dart';
import '../domain/usecases/stop_conversation_usecase.dart';
import '../presentation/bloc/home_bloc.dart';

void setupHomeModule(GetIt sl) {
  final supabaseClient = Supabase.instance.client;

  // Database
  sl.registerSingleton<AppDatabase>(AppDatabase());

  // Datasources
  sl.registerLazySingleton<ConversationRemoteDataSource>(
    () => ConversationRemoteDataSourceImpl(supabaseClient),
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

  // BLoC
  sl.registerFactory<HomeBloc>(
    () => HomeBloc(
      fetchTokenUseCase: sl<FetchConversationTokenUseCase>(),
      startConversationUseCase: sl<StartConversationUseCase>(),
      stopConversationUseCase: sl<StopConversationUseCase>(),
      conversationRepository: sl<ConversationRepository>(),
      firebaseAuth: FirebaseAuth.instance,
    ),
  );
}
