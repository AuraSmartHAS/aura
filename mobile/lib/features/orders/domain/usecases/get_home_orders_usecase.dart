import 'package:aura/core/errors/result.dart';
import '../entities/order_detail.dart';
import '../repositories/orders_repository.dart';

class GetHomeOrdersUseCase {
  GetHomeOrdersUseCase(this._repository);

  final OrdersRepository _repository;

  Future<Result<List<OrderSummary>>> call(String homeId) =>
      _repository.getHomeOrders(homeId);
}
