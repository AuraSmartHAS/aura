import 'package:dio/dio.dart';

import 'package:aura/core/network/api_client.dart';

abstract class CareFeedRemoteDataSource {
  Future<List<dynamic>> getSignals(String homeId,
      {required int limit, DateTime? since, String? type});

  /// `null` no 204: sem SOS em aberto.
  Future<Map<String, dynamic>?> getActiveEmergency(String homeId);

  Future<Map<String, dynamic>> acknowledge(String emergencyId);

  /// `GET /emergencies/{id}`: estado do aviso (rota aberta e magra).
  Future<Map<String, dynamic>> getEmergency(String emergencyId);
}

class CareFeedRemoteDataSourceImpl implements CareFeedRemoteDataSource {
  CareFeedRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  @override
  Future<List<dynamic>> getSignals(String homeId,
      {required int limit, DateTime? since, String? type}) async {
    final res = await _dio.get(
      '/homes/$homeId/signals',
      queryParameters: {
        'limit': limit,
        if (type != null) 'type': type,
        if (since != null) 'from': since.toUtc().toIso8601String(),
      },
    );
    return res.data as List<dynamic>;
  }

  @override
  Future<Map<String, dynamic>?> getActiveEmergency(String homeId) async {
    final res = await _dio.get('/homes/$homeId/emergencies/active');
    if (res.statusCode == 204 || res.data == null || res.data == '') {
      return null;
    }
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getEmergency(String emergencyId) async {
    final res = await _dio.get('/emergencies/$emergencyId');
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> acknowledge(String emergencyId) async {
    final res = await _dio.post('/emergencies/$emergencyId/ack');
    return res.data as Map<String, dynamic>;
  }
}
