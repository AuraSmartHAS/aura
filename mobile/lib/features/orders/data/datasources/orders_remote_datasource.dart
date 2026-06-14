import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';

abstract class OrdersRemoteDataSource {
  Future<Map<String, dynamic>> getOrder(String orderId);
  Future<List<dynamic>> getHomeOrders(String homeId);
  Future<Map<String, dynamic>> advance(String orderId);
}

class OrdersRemoteDataSourceImpl implements OrdersRemoteDataSource {
  OrdersRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  @override
  Future<Map<String, dynamic>> getOrder(String orderId) async {
    final res = await _dio.get('/orders/$orderId');
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<List<dynamic>> getHomeOrders(String homeId) async {
    final res = await _dio.get('/homes/$homeId/orders');
    return res.data as List<dynamic>;
  }

  @override
  Future<Map<String, dynamic>> advance(String orderId) async {
    final res = await _dio.post('/orders/$orderId/advance');
    return res.data as Map<String, dynamic>;
  }
}
