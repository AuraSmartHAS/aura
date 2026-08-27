part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class HomeInitEvent extends HomeEvent {
  const HomeInitEvent();
}

class HomeMicTappedEvent extends HomeEvent {
  const HomeMicTappedEvent();
}

class HomeStatusChangedEvent extends HomeEvent {
  final ConversationStatus status;
  final ConversationMode mode;

  const HomeStatusChangedEvent({
    required this.status,
    required this.mode,
  });

  @override
  List<Object?> get props => [status, mode];
}

class HomeTranscriptChangedEvent extends HomeEvent {
  final List<TranscriptMessageEntity> transcript;

  const HomeTranscriptChangedEvent(this.transcript);

  @override
  List<Object?> get props => [transcript];
}

class HomeMuteToggledEvent extends HomeEvent {
  final bool isMuted;

  const HomeMuteToggledEvent(this.isMuted);

  @override
  List<Object?> get props => [isMuted];
}

class HomeModeChangedEvent extends HomeEvent {
  final ConversationMode mode;

  const HomeModeChangedEvent(this.mode);

  @override
  List<Object?> get props => [mode];
}

/// "Prefiro digitar": abre o caminho não-vocal. Conecta a sessão com o
/// microfone mudo — nunca liga o microfone (regressão R-10).
class HomeTextModeRequestedEvent extends HomeEvent {
  const HomeTextModeRequestedEvent();
}

/// "Prefiro falar": volta ao microfone sem derrubar a conversa.
class HomeVoiceModeRequestedEvent extends HomeEvent {
  const HomeVoiceModeRequestedEvent();
}

/// Texto escrito ou chip de intenção tocado — os dois viram a mesma mensagem.
class HomeTextSubmittedEvent extends HomeEvent {
  final String text;

  const HomeTextSubmittedEvent(this.text);

  @override
  List<Object?> get props => [text];
}

/// "Ouvir de novo": repete a última fala da Aura.
class HomeRepeatLastReplyEvent extends HomeEvent {
  const HomeRepeatLastReplyEvent();
}

/// Erro vindo do callback `onError` da sessão de voz.
class HomeErrorReceivedEvent extends HomeEvent {
  final String message;

  const HomeErrorReceivedEvent(this.message);

  @override
  List<Object?> get props => [message];
}

/// Passou o tempo de espera sem resposta da Maria.
class HomeSilenceDetectedEvent extends HomeEvent {
  const HomeSilenceDetectedEvent();
}
