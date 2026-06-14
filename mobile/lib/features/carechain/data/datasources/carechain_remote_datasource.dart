import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';

abstract class CareChainRemoteDataSource {
  Future<List<dynamic>> getCatalog({String? riskTag});
  Future<Map<String, dynamic>> getCatalogItem(String sku);
  Future<Map<String, dynamic>> createRecommendation(
    String homeId, {
    String? scoreId,
  });
  Future<Map<String, dynamic>> approve(String recId);
}

class CareChainRemoteDataSourceImpl implements CareChainRemoteDataSource {
  CareChainRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  @override
  Future<List<dynamic>> getCatalog({String? riskTag}) async {
    final res = await _dio.get(
      '/catalog',
      queryParameters: {if (riskTag != null) 'riskTag': riskTag},
    );
    return res.data as List<dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getCatalogItem(String sku) async {
    final res = await _dio.get('/catalog/$sku');
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> createRecommendation(
    String homeId, {
    String? scoreId,
  }) async {
    final res = await _dio.post('/recommendations', data: {
      'homeId': homeId,
      if (scoreId != null) 'scoreId': scoreId,
    });
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> approve(String recId) async {
    final res = await _dio.post('/recommendations/$recId/approve');
    return res.data as Map<String, dynamic>;
  }
}
