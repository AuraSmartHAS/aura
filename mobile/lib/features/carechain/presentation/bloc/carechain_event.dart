part of 'carechain_bloc.dart';

abstract class CareChainEvent extends Equatable {
  const CareChainEvent();

  @override
  List<Object?> get props => [];
}

class LoadRecommendationEvent extends CareChainEvent {
  const LoadRecommendationEvent();
}

class ApproveRecommendationEvent extends CareChainEvent {
  const ApproveRecommendationEvent(this.recommendationId);

  final String recommendationId;

  @override
  List<Object?> get props => [recommendationId];
}
