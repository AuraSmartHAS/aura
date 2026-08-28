import 'package:dio/dio.dart';

import 'package:aura/core/network/api_client.dart';

/// Rotas do SOS (`docs/api/openapi.json`, tag "8. SOS e crise").
///
/// As três usadas aqui são **abertas** (`security: []`). O `AuthInterceptor`
/// continua no caminho e ainda põe o Bearer quando existe um — o que não
/// atrapalha: sem token válido a rota responde igual. É o que faz o socorro
/// funcionar com a sessão expirada.
abstract class EmergencyRemoteDataSource {
  Future<Map<String, dynamic>> trigger({
    required String homeId,
    required String channel,
  });

  Future<Map<String, dynamic>> cancel(String emergencyId);

  Future<Map<String, dynamic>> status(String emergencyId);
}

class EmergencyRemoteDataSourceImpl implements EmergencyRemoteDataSource {
  EmergencyRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  @override
  Future<Map<String, dynamic>> trigger({
    required String homeId,
    required String channel,
  }) async {
    final res = await _dio.post(
      '/emergencies',
      data: {'homeId': homeId, 'channel': channel},
    );
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> cancel(String emergencyId) async {
    final res = await _dio.post('/emergencies/$emergencyId/cancel');
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> status(String emergencyId) async {
    final res = await _dio.get('/emergencies/$emergencyId');
    return res.data as Map<String, dynamic>;
  }
}
