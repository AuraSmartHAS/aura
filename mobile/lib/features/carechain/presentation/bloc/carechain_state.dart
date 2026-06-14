part of 'carechain_bloc.dart';

enum CareChainStatus { loading, ready, empty, error }

class CareChainState extends Equatable {
  const CareChainState({
    required this.status,
    this.recommendation,
    this.isApproving = false,
    this.approvedOrderId,
    this.errorMessage,
  });

  const CareChainState.loading()
      : status = CareChainStatus.loading,
        recommendation = null,
        isApproving = false,
        approvedOrderId = null,
        errorMessage = null;

  const CareChainState.ready(this.recommendation)
      : status = CareChainStatus.ready,
        isApproving = false,
        approvedOrderId = null,
        errorMessage = null;

  const CareChainState.empty()
      : status = CareChainStatus.empty,
        recommendation = null,
        isApproving = false,
        approvedOrderId = null,
        errorMessage = null;

  const CareChainState.error(this.errorMessage)
      : status = CareChainStatus.error,
        recommendation = null,
        isApproving = false,
        approvedOrderId = null;

  final CareChainStatus status;
  final Recommendation? recommendation;
  final bool isApproving;
  final String? approvedOrderId;
  final String? errorMessage;

  CareChainState copyWith({
    bool? isApproving,
    String? approvedOrderId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CareChainState(
      status: status,
      recommendation: recommendation,
      isApproving: isApproving ?? this.isApproving,
      approvedOrderId: approvedOrderId ?? this.approvedOrderId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        recommendation?.recommendationId,
        isApproving,
        approvedOrderId,
        errorMessage,
      ];
}
