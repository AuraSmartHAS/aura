/// Logistics order stages (aura-server `order.stage`), in pipeline order.
enum OrderStage {
  approved,
  sourcing,
  inRoute,
  delivered,
  installed,
  returned;

  static OrderStage fromApi(String? stage) {
    switch (stage) {
      case 'sourcing':
        return OrderStage.sourcing;
      case 'in_route':
        return OrderStage.inRoute;
      case 'delivered':
        return OrderStage.delivered;
      case 'installed':
        return OrderStage.installed;
      case 'returned':
        return OrderStage.returned;
      case 'approved':
      default:
        return OrderStage.approved;
    }
  }

  String get apiValue {
    switch (this) {
      case OrderStage.inRoute:
        return 'in_route';
      default:
        return name;
    }
  }

  String get label {
    switch (this) {
      case OrderStage.approved:
        return 'Pedido';
      case OrderStage.sourcing:
        return 'Separação';
      case OrderStage.inRoute:
        return 'Rota';
      case OrderStage.delivered:
        return 'Entregue';
      case OrderStage.installed:
        return 'Instalado';
      case OrderStage.returned:
        return 'Reversa';
    }
  }
}
