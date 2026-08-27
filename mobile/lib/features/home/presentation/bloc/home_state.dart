part of 'home_bloc.dart';

enum VoiceUIState {
  idle,
  connecting,
  listening,
  speaking,
  error,
}

class HomeState extends Equatable {
  final bool isLoading;
  final String? userName;
  final VoiceUIState voiceState;
  final List<TranscriptMessageEntity> transcript;
  final bool isMuted;
  final String? errorMessage;

  /// Caminho não-vocal aberto: campo de texto e chips no lugar do microfone.
  final bool isTextMode;

  /// Chips de intenção em destaque — ligado quando a Aura não ouviu resposta.
  final bool intentsHighlighted;

  /// Aviso calmo para a Maria (não é erro): "Não te ouvi bem", a última fala
  /// repetida, o convite para escrever.
  final String? notice;

  /// Muda a cada aviso novo para que o mesmo texto possa ser anunciado de novo
  /// ao leitor de tela (tocar "Ouvir de novo" duas vezes tem de falar duas).
  final int noticeId;

  const HomeState({
    this.isLoading = true,
    this.userName,
    this.voiceState = VoiceUIState.idle,
    this.transcript = const [],
    this.isMuted = false,
    this.errorMessage,
    this.isTextMode = false,
    this.intentsHighlighted = false,
    this.notice,
    this.noticeId = 0,
  });

  HomeState copyWith({
    bool? isLoading,
    String? userName,
    VoiceUIState? voiceState,
    List<TranscriptMessageEntity>? transcript,
    bool? isMuted,
    String? errorMessage,
    bool clearError = false,
    bool? isTextMode,
    bool? intentsHighlighted,
    String? notice,
    int? noticeId,
    bool clearNotice = false,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      userName: userName ?? this.userName,
      voiceState: voiceState ?? this.voiceState,
      transcript: transcript ?? this.transcript,
      isMuted: isMuted ?? this.isMuted,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isTextMode: isTextMode ?? this.isTextMode,
      intentsHighlighted: intentsHighlighted ?? this.intentsHighlighted,
      notice: clearNotice ? null : (notice ?? this.notice),
      noticeId: noticeId ?? this.noticeId,
    );
  }

  /// A sessão está de pé — é a condição que o SDK exige para aceitar texto.
  bool get isSessionLive =>
      voiceState == VoiceUIState.listening ||
      voiceState == VoiceUIState.speaking;

  /// Última resposta da Aura, se houver alguma.
  String? get lastAuraReply {
    for (var i = transcript.length - 1; i >= 0; i--) {
      if (!transcript[i].isUser) return transcript[i].text;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        isLoading,
        userName,
        voiceState,
        transcript,
        isMuted,
        errorMessage,
        isTextMode,
        intentsHighlighted,
        notice,
        noticeId,
      ];
}
