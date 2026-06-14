import 'package:aura/shared/models/order_stage.dart';

/// Full order detail (`GET /orders/{id}`): stage, SLA, delivery route/ETA.
class OrderDetail {
  const OrderDetail({
    required this.orderId,
    required this.stage,
    this.slaDueAt,
    this.slaBreached = false,
    this.deliveredAt,
    this.installedAt,
    this.eta,
    this.distanceM,
    this.durationS,
    this.deliveryStatus,
    this.routeCoordinates = const [],
  });

  final String orderId;
  final OrderStage stage;

  final DateTime? slaDueAt;
  final bool slaBreached;
  final DateTime? deliveredAt;
  final DateTime? installedAt;

  final DateTime? eta;
  final int? distanceM;
  final int? durationS;
  final String? deliveryStatus;

  /// GeoJSON LineString coordinates as `[lng, lat]` pairs.
  final List<List<double>> routeCoordinates;

  bool get hasRoute => routeCoordinates.length >= 2;
}

/// Lightweight order list item (`GET /homes/{id}/orders`).
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.stage,
    required this.sku,
    this.slaBreached = false,
    this.slaDueAt,
    this.createdAt,
  });

  final String id;
  final OrderStage stage;
  final String sku;
  final bool slaBreached;
  final DateTime? slaDueAt;
  final DateTime? createdAt;
}
