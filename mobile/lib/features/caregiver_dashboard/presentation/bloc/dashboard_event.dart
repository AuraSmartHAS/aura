part of 'dashboard_bloc.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboardEvent extends DashboardEvent {
  const LoadDashboardEvent();
}

/// Atualização silenciosa (sem tela de carregando): o SOS em aberto e os
/// sinais novos. Não há push para a família nesta versão, então é o polling
/// que a faz descobrir um pedido de ajuda.
class DashboardPolledEvent extends DashboardEvent {
  const DashboardPolledEvent();
}

/// "Estou indo": a família confirma o SOS em aberto.
class AcknowledgeEmergencyEvent extends DashboardEvent {
  const AcknowledgeEmergencyEvent(this.emergencyId);

  final String emergencyId;

  @override
  List<Object?> get props => [emergencyId];
}
