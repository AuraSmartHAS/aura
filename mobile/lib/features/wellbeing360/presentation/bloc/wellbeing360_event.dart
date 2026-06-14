part of 'wellbeing360_bloc.dart';

abstract class Wellbeing360Event extends Equatable {
  const Wellbeing360Event();

  @override
  List<Object?> get props => [];
}

class LoadScoresEvent extends Wellbeing360Event {
  const LoadScoresEvent();
}

class RecomputeScoresEvent extends Wellbeing360Event {
  const RecomputeScoresEvent({this.dimension});

  /// Null recomputes all dimensions (backend returns the highest risk).
  final String? dimension;

  @override
  List<Object?> get props => [dimension];
}
