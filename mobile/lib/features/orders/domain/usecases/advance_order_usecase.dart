import 'package:aura/core/errors/result.dart';
import '../entities/order_detail.dart';
import '../repositories/orders_repository.dart';

class AdvanceOrderUseCase {
  AdvanceOrderUseCase(this._repository);

  final OrdersRepository _repository;

  Future<Result<OrderDetail>> call(String orderId) =>
      _repository.advance(orderId);
}
