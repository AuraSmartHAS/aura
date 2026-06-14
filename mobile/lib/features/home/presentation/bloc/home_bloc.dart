import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/transcript_message_entity.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../../domain/usecases/fetch_conversation_token_usecase.dart';
import '../../domain/usecases/start_conversation_usecase.dart';
import '../../domain/usecases/stop_conversation_usecase.dart';
import 'package:aura/core/errors/result.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final FetchConversationTokenUseCase _fetchTokenUseCase;
  final StartConversationUseCase _startConversationUseCase;
  final StopConversationUseCase _stopConversationUseCase;
  final ConversationRepository _conversationRepository;

  late StreamSubscription<ConversationStatus> _statusSubscription;
  late StreamSubscription<ConversationMode> _modeSubscription;
  late StreamSubscription<List<TranscriptMessageEntity>> _transcriptSubscription;
  late StreamSubscription<bool> _muteSubscription;

  ConversationMode _currentMode = ConversationMode.listening;
  String? _conversationToken;

  HomeBloc({
    required FetchConversationTokenUseCase fetchTokenUseCase,
    required StartConversationUseCase startConversationUseCase,
    required StopConversationUseCase stopConversationUseCase,
    required ConversationRepository conversationRepository,
  })  : _fetchTokenUseCase = fetchTokenUseCase,
        _startConversationUseCase = startConversationUseCase,
        _stopConversationUseCase = stopConversationUseCase,
        _conversationRepository = conversationRepository,
        super(const HomeState()) {
    on<HomeInitEvent>(_onInit);
    on<HomeMicTappedEvent>(_onMicTapped);
    on<HomeStatusChangedEvent>(_onStatusChanged);
    on<HomeTranscriptChangedEvent>(_onTranscriptChanged);
    on<HomeMuteToggledEvent>(_onMuteToggled);
    on<HomeModeChangedEvent>(_onModeChanged);
  }

  Future<void> _onInit(HomeInitEvent event, Emitter<HomeState> emit) async {
    emit(state.copyWith(isLoading: true));

    _setupStreamListeners();

    final tokenResult = await _fetchTokenUseCase();
    if (tokenResult is Success<String>) {
      _conversationToken = tokenResult.data;
    }

    emit(state.copyWith(isLoading: false, userName: 'Maria'));
  }

  void _setupStreamListeners() {
    _statusSubscription = _conversationRepository.statusStream.listen((status) {
      add(HomeStatusChangedEvent(status: status, mode: _currentMode));
    });

    _modeSubscription = _conversationRepository.modeStream.listen((mode) {
      _currentMode = mode;
      add(HomeModeChangedEvent(mode));
    });

    _transcriptSubscription = _conversationRepository.transcriptStream.listen((transcript) {
      add(HomeTranscriptChangedEvent(transcript));
    });

    _muteSubscription = _conversationRepository.isMutedStream.listen((isMuted) {
      add(HomeMuteToggledEvent(isMuted));
    });
  }

  Future<void> _onMicTapped(HomeMicTappedEvent event, Emitter<HomeState> emit) async {
    if (state.voiceState == VoiceUIState.idle) {
      if (_conversationToken == null) {
        emit(state.copyWith(
          voiceState: VoiceUIState.error,
          errorMessage: 'Token not available. Please try again.',
        ));
        return;
      }
      emit(state.copyWith(voiceState: VoiceUIState.connecting));
      final result = await _startConversationUseCase(_conversationToken!);
      if (result is Failure<void>) {
        emit(state.copyWith(
          voiceState: VoiceUIState.error,
          errorMessage: 'Failed to start conversation',
        ));
      }
    } else {
      emit(state.copyWith(voiceState: VoiceUIState.idle));
      await _stopConversationUseCase();
    }
  }

  Future<void> _onStatusChanged(
    HomeStatusChangedEvent event,
    Emitter<HomeState> emit,
  ) async {
    final voiceState = _mapStatusToVoiceState(event.status, event.mode);
    emit(state.copyWith(voiceState: voiceState));
  }

  Future<void> _onTranscriptChanged(
    HomeTranscriptChangedEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(transcript: event.transcript));
  }

  Future<void> _onMuteToggled(
    HomeMuteToggledEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isMuted: event.isMuted));
  }

  Future<void> _onModeChanged(
    HomeModeChangedEvent event,
    Emitter<HomeState> emit,
  ) async {
    final isActive = state.voiceState == VoiceUIState.listening ||
        state.voiceState == VoiceUIState.speaking;
    if (isActive) {
      final voiceState = event.mode == ConversationMode.speaking
          ? VoiceUIState.speaking
          : VoiceUIState.listening;
      emit(state.copyWith(voiceState: voiceState));
    }
  }

  VoiceUIState _mapStatusToVoiceState(
    ConversationStatus status,
    ConversationMode mode,
  ) {
    switch (status) {
      case ConversationStatus.disconnected:
      case ConversationStatus.disconnecting:
        return VoiceUIState.idle;
      case ConversationStatus.connecting:
        return VoiceUIState.connecting;
      case ConversationStatus.connected:
        return mode == ConversationMode.listening
            ? VoiceUIState.listening
            : VoiceUIState.speaking;
      case ConversationStatus.error:
        return VoiceUIState.error;
    }
  }

  @override
  Future<void> close() {
    _statusSubscription.cancel();
    _modeSubscription.cancel();
    _transcriptSubscription.cancel();
    _muteSubscription.cancel();
    return super.close();
  }
}
