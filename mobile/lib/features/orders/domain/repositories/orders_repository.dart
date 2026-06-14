import 'package:aura/core/errors/result.dart';
import '../entities/order_detail.dart';

abstract class OrdersRepository {
  Future<Result<OrderDetail>> getOrder(String orderId);
  Future<Result<List<OrderSummary>>> getHomeOrders(String homeId);

  /// Advances the order one stage (demo/simulated logistics).
  Future<Result<OrderDetail>> advance(String orderId);
}
