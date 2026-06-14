import 'package:aura/core/errors/result.dart';
import 'package:aura/core/network/error_mapper.dart';
import '../../domain/entities/order_detail.dart';
import '../../domain/repositories/orders_repository.dart';
import '../datasources/orders_remote_datasource.dart';
import '../models/order_mapper.dart';

class OrdersRepositoryImpl implements OrdersRepository {
  OrdersRepositoryImpl(this._remoteDataSource);

  final OrdersRemoteDataSource _remoteDataSource;

  @override
  Future<Result<OrderDetail>> getOrder(String orderId) async {
    try {
      final data = await _remoteDataSource.getOrder(orderId);
      return Success(orderDetailFromJson(data));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<List<OrderSummary>>> getHomeOrders(String homeId) async {
    try {
      final data = await _remoteDataSource.getHomeOrders(homeId);
      return Success(
        data
            .map((e) => orderSummaryFromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<OrderDetail>> advance(String orderId) async {
    try {
      // advance returns a partial payload; re-fetch for the full detail.
      await _remoteDataSource.advance(orderId);
      final data = await _remoteDataSource.getOrder(orderId);
      return Success(orderDetailFromJson(data));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }
}
