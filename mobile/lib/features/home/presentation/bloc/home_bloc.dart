import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/transcript_message_entity.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../../domain/usecases/fetch_conversation_token_usecase.dart';
import '../../domain/usecases/send_text_message_usecase.dart';
import '../../domain/usecases/start_conversation_usecase.dart';
import '../../domain/usecases/stop_conversation_usecase.dart';
import '../../domain/usecases/toggle_mute_usecase.dart';
import 'package:aura/core/errors/result.dart';

part 'home_event.dart';
part 'home_state.dart';

/// Pedido de repetição enviado pelo botão "Ouvir de novo" quando a sessão está
/// viva — é o único jeito de a Aura falar de novo em voz alta.
const String kRepeatRequest = 'Pode repetir, por favor?';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final FetchConversationTokenUseCase _fetchTokenUseCase;
  final StartConversationUseCase _startConversationUseCase;
  final StopConversationUseCase _stopConversationUseCase;
  final SendTextMessageUseCase _sendTextMessageUseCase;
  final ToggleMuteUseCase _toggleMuteUseCase;
  final ConversationRepository _conversationRepository;

  /// Espera antes de assumir que a Maria não respondeu. Injetável para o teste
  /// não precisar esperar 12 segundos de verdade.
  final Duration silenceTimeout;

  StreamSubscription<ConversationStatus>? _statusSubscription;
  StreamSubscription<ConversationMode>? _modeSubscription;
  StreamSubscription<List<TranscriptMessageEntity>>? _transcriptSubscription;
  StreamSubscription<bool>? _muteSubscription;
  StreamSubscription<String>? _errorSubscription;

  Timer? _silenceTimer;
  int _unansweredTurns = 0;
  int _noticeSeq = 0;

  ConversationMode _currentMode = ConversationMode.listening;
  String? _conversationToken;

  HomeBloc({
    required FetchConversationTokenUseCase fetchTokenUseCase,
    required StartConversationUseCase startConversationUseCase,
    required StopConversationUseCase stopConversationUseCase,
    required SendTextMessageUseCase sendTextMessageUseCase,
    required ToggleMuteUseCase toggleMuteUseCase,
    required ConversationRepository conversationRepository,
    this.silenceTimeout = const Duration(seconds: 12),
  })  : _fetchTokenUseCase = fetchTokenUseCase,
        _startConversationUseCase = startConversationUseCase,
        _stopConversationUseCase = stopConversationUseCase,
        _sendTextMessageUseCase = sendTextMessageUseCase,
        _toggleMuteUseCase = toggleMuteUseCase,
        _conversationRepository = conversationRepository,
        super(const HomeState()) {
    on<HomeInitEvent>(_onInit);
    on<HomeMicTappedEvent>(_onMicTapped);
    on<HomeStatusChangedEvent>(_onStatusChanged);
    on<HomeTranscriptChangedEvent>(_onTranscriptChanged);
    on<HomeMuteToggledEvent>(_onMuteToggled);
    on<HomeModeChangedEvent>(_onModeChanged);
    on<HomeTextModeRequestedEvent>(_onTextModeRequested);
    on<HomeVoiceModeRequestedEvent>(_onVoiceModeRequested);
    on<HomeTextSubmittedEvent>(_onTextSubmitted);
    on<HomeRepeatLastReplyEvent>(_onRepeatLastReply);
    on<HomeErrorReceivedEvent>(_onErrorReceived);
    on<HomeSilenceDetectedEvent>(_onSilenceDetected);
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

    _errorSubscription = _conversationRepository.errorStream.listen((message) {
      add(HomeErrorReceivedEvent(message));
    });
  }

  Future<void> _onMicTapped(HomeMicTappedEvent event, Emitter<HomeState> emit) async {
    if (state.voiceState == VoiceUIState.idle ||
        state.voiceState == VoiceUIState.error) {
      if (_conversationToken == null) {
        emit(state.copyWith(
          voiceState: VoiceUIState.error,
          errorMessage: 'Não consegui falar com a Aura agora. '
              'Tente de novo em um instante.',
        ));
        return;
      }
      emit(state.copyWith(
        voiceState: VoiceUIState.connecting,
        isTextMode: false,
        clearError: true,
      ));
      final result = await _startConversationUseCase(_conversationToken!);
      if (result is Failure<void>) {
        emit(state.copyWith(
          voiceState: VoiceUIState.error,
          errorMessage: 'Não consegui começar a conversa. Toque para tentar de novo.',
        ));
      }
    } else if (state.isMuted) {
      // Veio do modo texto: o microfone estava mudo de propósito. Tocar nele
      // devolve a voz sem derrubar a conversa que já está em pé.
      emit(state.copyWith(isTextMode: false, clearError: true));
      await _toggleMuteUseCase(false);
    } else {
      emit(state.copyWith(voiceState: VoiceUIState.idle, isTextMode: false));
      _cancelSilenceWatch();
      await _stopConversationUseCase();
    }
  }

  Future<void> _onStatusChanged(
    HomeStatusChangedEvent event,
    Emitter<HomeState> emit,
  ) async {
    final voiceState = _mapStatusToVoiceState(event.status, event.mode);
    emit(state.copyWith(voiceState: voiceState));
    _syncSilenceWatch();
  }

  Future<void> _onTranscriptChanged(
    HomeTranscriptChangedEvent event,
    Emitter<HomeState> emit,
  ) async {
    final last = event.transcript.isEmpty ? null : event.transcript.last;
    final userAnswered = last?.isUser ?? false;
    if (userAnswered) {
      _unansweredTurns = 0;
    }

    emit(state.copyWith(
      transcript: event.transcript,
      intentsHighlighted: userAnswered ? false : null,
      // O aviso ("Não te ouvi bem", a fala repetida) sai da tela quando a Aura
      // responde de novo — não quando a Maria manda a mensagem.
      clearNotice: last != null && !last.isUser,
    ));
    _syncSilenceWatch();
  }

  Future<void> _onMuteToggled(
    HomeMuteToggledEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isMuted: event.isMuted));
    _syncSilenceWatch();
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
      _syncSilenceWatch();
    }
  }

  // ── Caminho não-vocal (C4) ───────────────────────────────────────

  Future<void> _onTextModeRequested(
    HomeTextModeRequestedEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isTextMode: true, clearError: true));
    await _ensureSessionForText(emit);
  }

  Future<void> _onVoiceModeRequested(
    HomeVoiceModeRequestedEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(
      isTextMode: false,
      intentsHighlighted: false,
      clearNotice: true,
    ));
    if (state.isSessionLive && state.isMuted) {
      await _toggleMuteUseCase(false);
    }
  }

  Future<void> _onTextSubmitted(
    HomeTextSubmittedEvent event,
    Emitter<HomeState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty) return;

    _cancelSilenceWatch();
    emit(state.copyWith(intentsHighlighted: false, clearError: true));

    final ready = await _ensureSessionForText(emit);
    if (!ready) return;

    final result = await _sendTextMessageUseCase(text);
    if (result is Failure<void>) {
      emit(state.copyWith(
        errorMessage: 'Não consegui enviar sua mensagem. Tente de novo.',
      ));
      return;
    }
    _unansweredTurns = 0;
  }

  Future<void> _onRepeatLastReply(
    HomeRepeatLastReplyEvent event,
    Emitter<HomeState> emit,
  ) async {
    final lastReply = state.lastAuraReply;
    if (lastReply == null) {
      emit(_withNotice('Ainda não te disse nada nesta conversa.'));
      return;
    }

    // Duas metades do mesmo pedido: o texto volta grande na tela (e é anunciado
    // ao leitor de tela) e, com a sessão viva, a Aura repete em voz alta.
    emit(_withNotice(lastReply));
    if (state.isSessionLive) {
      await _sendTextMessageUseCase(kRepeatRequest);
    }
  }

  Future<void> _onErrorReceived(
    HomeErrorReceivedEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(errorMessage: _errorInPtBr(event.message)));
  }

  Future<void> _onSilenceDetected(
    HomeSilenceDetectedEvent event,
    Emitter<HomeState> emit,
  ) async {
    _unansweredTurns++;

    if (_unansweredTurns >= 2) {
      // Duas falhas seguidas: o app deixa de esperar a voz e leva a Maria ao
      // caminho que não depende de falar.
      emit(_withNotice(
        'Vamos tentar de outro jeito: toque em uma frase ou escreva para mim.',
      ).copyWith(isTextMode: true, intentsHighlighted: true));
      await _toggleMuteUseCase(true);
      return;
    }

    emit(_withNotice('Não te ouvi bem. Toque em uma das frases abaixo.')
        .copyWith(intentsHighlighted: true));
    _syncSilenceWatch();
  }

  /// Garante uma sessão pronta para receber texto. **Conectar liga o
  /// microfone**, então no caminho escrito ele nasce mudo: usar o app sem falar
  /// não pode passar pela permissão do microfone.
  Future<bool> _ensureSessionForText(Emitter<HomeState> emit) async {
    if (state.isSessionLive) {
      if (!state.isMuted) {
        await _toggleMuteUseCase(true);
      }
      return true;
    }

    if (_conversationToken == null) {
      emit(state.copyWith(
        errorMessage: 'Não consegui falar com a Aura agora. '
            'Tente de novo em um instante.',
      ));
      return false;
    }

    emit(state.copyWith(voiceState: VoiceUIState.connecting));
    final result = await _startConversationUseCase(_conversationToken!);
    if (result is Failure<void>) {
      emit(state.copyWith(
        voiceState: VoiceUIState.error,
        errorMessage: 'Não consegui começar a conversa. Tente de novo.',
      ));
      return false;
    }

    await _toggleMuteUseCase(true);
    return true;
  }

  HomeState _withNotice(String message) {
    _noticeSeq++;
    return state.copyWith(notice: message, noticeId: _noticeSeq);
  }

  // ── Espera sem resposta ──────────────────────────────────────────

  void _syncSilenceWatch() {
    // Só faz sentido esperar a voz quando o microfone está aberto: no modo
    // texto o silêncio é escolha, não falha.
    final shouldWatch = state.voiceState == VoiceUIState.listening &&
        !state.isMuted &&
        !state.isTextMode;
    _cancelSilenceWatch();
    if (!shouldWatch) return;

    _silenceTimer = Timer(silenceTimeout, () {
      if (isClosed) return;
      add(const HomeSilenceDetectedEvent());
    });
  }

  void _cancelSilenceWatch() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
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
    _cancelSilenceWatch();
    _statusSubscription?.cancel();
    _modeSubscription?.cancel();
    _transcriptSubscription?.cancel();
    _muteSubscription?.cancel();
    _errorSubscription?.cancel();
    return super.close();
  }
}

/// Dicionário mínimo dos erros que a sessão de voz reporta em inglês pelo
/// `onError`. O dicionário completo é a correção C6; aqui entra só o que o
/// caminho escrito pode encontrar.
String _errorInPtBr(String rawMessage) {
  final message = rawMessage.toLowerCase();
  if (message.contains('send message') || message.contains('user message')) {
    return 'Não consegui enviar sua mensagem. Tente de novo.';
  }
  if (message.contains('mic')) {
    return 'Não consegui usar o microfone. Você pode escrever para mim.';
  }
  if (message.contains('session') || message.contains('connect')) {
    return 'A conversa caiu. Toque no microfone para começar de novo.';
  }
  return 'Alguma coisa não funcionou aqui. Tente de novo em um instante.';
}
