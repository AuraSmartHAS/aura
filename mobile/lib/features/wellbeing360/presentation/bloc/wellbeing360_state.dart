part of 'wellbeing360_bloc.dart';

enum Wellbeing360Status { loading, ready, error }

class Wellbeing360State extends Equatable {
  const Wellbeing360State({
    required this.status,
    this.scores = const [],
    this.errorMessage,
    this.isRecomputing = false,
  });

  const Wellbeing360State.loading()
      : status = Wellbeing360Status.loading,
        scores = const [],
        errorMessage = null,
        isRecomputing = false;

  const Wellbeing360State.ready(this.scores)
      : status = Wellbeing360Status.ready,
        errorMessage = null,
        isRecomputing = false;

  const Wellbeing360State.error(this.errorMessage)
      : status = Wellbeing360Status.error,
        scores = const [],
        isRecomputing = false;

  final Wellbeing360Status status;
  final List<Score> scores;
  final String? errorMessage;
  final bool isRecomputing;

  Wellbeing360State copyWith({bool? isRecomputing}) {
    return Wellbeing360State(
      status: status,
      scores: scores,
      errorMessage: errorMessage,
      isRecomputing: isRecomputing ?? this.isRecomputing,
    );
  }

  @override
  List<Object?> get props => [status, scores, errorMessage, isRecomputing];
}
