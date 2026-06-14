import 'package:aura/shared/models/order_stage.dart';
import '../../domain/entities/order_detail.dart';

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

OrderDetail orderDetailFromJson(Map<String, dynamic> json) {
  final sla = json['sla'] as Map<String, dynamic>?;
  final delivery = json['delivery'] as Map<String, dynamic>?;
  final route = delivery?['route'] as Map<String, dynamic>?;
  final coords = (route?['coordinates'] as List?)
          ?.map((p) => (p as List).map((n) => (n as num).toDouble()).toList())
          .toList() ??
      <List<double>>[];

  return OrderDetail(
    orderId: json['orderId'] as String,
    stage: OrderStage.fromApi(json['stage'] as String?),
    slaDueAt: _date(sla?['dueAt']),
    slaBreached: (sla?['breached'] as bool?) ?? false,
    deliveredAt: _date(sla?['deliveredAt']),
    installedAt: _date(sla?['installedAt']),
    eta: _date(delivery?['eta']),
    distanceM: (delivery?['distanceM'] as num?)?.toInt(),
    durationS: (delivery?['durationS'] as num?)?.toInt(),
    deliveryStatus: delivery?['status'] as String?,
    routeCoordinates: coords,
  );
}

OrderSummary orderSummaryFromJson(Map<String, dynamic> json) {
  return OrderSummary(
    id: json['id'] as String,
    stage: OrderStage.fromApi(json['stage'] as String?),
    sku: (json['sku'] as String?) ?? '',
    slaBreached: (json['slaBreached'] as bool?) ?? false,
    slaDueAt: _date(json['slaDueAt']),
    createdAt: _date(json['createdAt']),
  );
}
