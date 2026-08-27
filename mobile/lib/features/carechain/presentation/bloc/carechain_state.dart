part of 'carechain_bloc.dart';

enum CareChainStatus { loading, ready, empty, error }

class CareChainState extends Equatable {
  const CareChainState({
    required this.status,
    this.recommendation,
    this.homeDetail,
    this.isApproving = false,
    this.approvedOrderId,
    this.errorMessage,
  });

  const CareChainState.loading()
      : status = CareChainStatus.loading,
        recommendation = null,
        homeDetail = null,
        isApproving = false,
        approvedOrderId = null,
        errorMessage = null;

  const CareChainState.ready({
    required this.recommendation,
    this.homeDetail,
  })  : status = CareChainStatus.ready,
        isApproving = false,
        approvedOrderId = null,
        errorMessage = null;

  const CareChainState.empty()
      : status = CareChainStatus.empty,
        recommendation = null,
        homeDetail = null,
        isApproving = false,
        approvedOrderId = null,
        errorMessage = null;

  const CareChainState.error(this.errorMessage)
      : status = CareChainStatus.error,
        recommendation = null,
        homeDetail = null,
        isApproving = false,
        approvedOrderId = null;

  final CareChainStatus status;
  final Recommendation? recommendation;

  /// Casa e paciente: quem mora onde o técnico vai entrar. Pode vir nulo — a
  /// folha de confirmação diz que o endereço não carregou em vez de inventar.
  final HomeDetail? homeDetail;

  final bool isApproving;
  final String? approvedOrderId;
  final String? errorMessage;

  String? get patientName => homeDetail?.patientName;
  String? get address => homeDetail?.home.address;

  /// Sem preço não se aprova (correção C5): a jornada de dinheiro não tem
  /// preço opcional.
  bool get canApprove => recommendation?.hasPrice ?? false;

  CareChainState copyWith({
    bool? isApproving,
    String? approvedOrderId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CareChainState(
      status: status,
      recommendation: recommendation,
      homeDetail: homeDetail,
      isApproving: isApproving ?? this.isApproving,
      approvedOrderId: approvedOrderId ?? this.approvedOrderId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        recommendation?.recommendationId,
        recommendation?.price,
        homeDetail?.home.id,
        homeDetail?.patientName,
        isApproving,
        approvedOrderId,
        errorMessage,
      ];
}
