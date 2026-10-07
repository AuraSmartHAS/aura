part of 'dashboard_bloc.dart';

enum DashboardStatus { loading, ready, error }

class DashboardState extends Equatable {
  const DashboardState({
    required this.status,
    this.homeDetail,
    this.topScore,
    this.errorMessage,
    this.userFirstName,
  });

  const DashboardState.loading()
      : status = DashboardStatus.loading,
        homeDetail = null,
        topScore = null,
        errorMessage = null,
        userFirstName = null;

  const DashboardState.ready({
    required this.homeDetail,
    this.topScore,
    this.userFirstName,
  })  : status = DashboardStatus.ready,
        errorMessage = null;

  const DashboardState.error(this.errorMessage)
      : status = DashboardStatus.error,
        homeDetail = null,
        topScore = null,
        userFirstName = null;

  final DashboardStatus status;
  final HomeDetail? homeDetail;
  final Score? topScore;
  final String? errorMessage;

  /// Primeiro nome de quem está logado, para a saudação; `null` cumprimenta
  /// sem nome.
  final String? userFirstName;

  @override
  List<Object?> get props => [
        status,
        homeDetail?.home.id,
        topScore?.scoreId,
        errorMessage,
        userFirstName,
      ];
}
