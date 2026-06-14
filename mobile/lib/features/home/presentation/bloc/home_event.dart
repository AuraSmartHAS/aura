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
