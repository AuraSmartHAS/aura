import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';

abstract class ScoresRemoteDataSource {
  Future<List<dynamic>> getScores(String homeId);
  Future<Map<String, dynamic>> recompute(String homeId, {String? dimension});
  Future<List<dynamic>> getSignals(String homeId, {String? type});
}

class ScoresRemoteDataSourceImpl implements ScoresRemoteDataSource {
  ScoresRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  @override
  Future<List<dynamic>> getScores(String homeId) async {
    final res = await _dio.get('/homes/$homeId/scores');
    return res.data as List<dynamic>;
  }

  @override
  Future<Map<String, dynamic>> recompute(
    String homeId, {
    String? dimension,
  }) async {
    final res = await _dio.post('/scores/recompute', data: {
      'homeId': homeId,
      if (dimension != null) 'dimension': dimension,
    });
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<List<dynamic>> getSignals(String homeId, {String? type}) async {
    final res = await _dio.get(
      '/homes/$homeId/signals',
      queryParameters: {if (type != null) 'type': type},
    );
    return res.data as List<dynamic>;
  }
}
