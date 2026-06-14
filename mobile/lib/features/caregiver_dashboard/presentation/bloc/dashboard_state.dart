part of 'dashboard_bloc.dart';

enum DashboardStatus { loading, ready, error }

class DashboardState extends Equatable {
  const DashboardState({
    required this.status,
    this.homeDetail,
    this.topScore,
    this.errorMessage,
  });

  const DashboardState.loading()
      : status = DashboardStatus.loading,
        homeDetail = null,
        topScore = null,
        errorMessage = null;

  const DashboardState.ready({required this.homeDetail, this.topScore})
      : status = DashboardStatus.ready,
        errorMessage = null;

  const DashboardState.error(this.errorMessage)
      : status = DashboardStatus.error,
        homeDetail = null,
        topScore = null;

  final DashboardStatus status;
  final HomeDetail? homeDetail;
  final Score? topScore;
  final String? errorMessage;

  @override
  List<Object?> get props =>
      [status, homeDetail?.home.id, topScore?.scoreId, errorMessage];
}
