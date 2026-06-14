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

  const HomeState({
    this.isLoading = true,
    this.userName,
    this.voiceState = VoiceUIState.idle,
    this.transcript = const [],
    this.isMuted = false,
    this.errorMessage,
  });

  HomeState copyWith({
    bool? isLoading,
    String? userName,
    VoiceUIState? voiceState,
    List<TranscriptMessageEntity>? transcript,
    bool? isMuted,
    String? errorMessage,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      userName: userName ?? this.userName,
      voiceState: voiceState ?? this.voiceState,
      transcript: transcript ?? this.transcript,
      isMuted: isMuted ?? this.isMuted,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [isLoading, userName, voiceState, transcript, isMuted, errorMessage];
}
