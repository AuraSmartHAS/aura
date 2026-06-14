import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';

abstract class HomeRemoteDataSource {
  Future<Map<String, dynamic>> createHome({
    required String patientName,
    String? birthDate,
    required String cep,
    String? label,
  });

  Future<Map<String, dynamic>> getHome(String homeId);

  Future<Map<String, dynamic>> updateChecklist(
    String homeId,
    Map<String, bool> items,
  );
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  HomeRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  @override
  Future<Map<String, dynamic>> createHome({
    required String patientName,
    String? birthDate,
    required String cep,
    String? label,
  }) async {
    final res = await _dio.post('/homes', data: {
      'patientName': patientName,
      if (birthDate != null) 'birthDate': birthDate,
      'cep': cep,
      if (label != null) 'label': label,
    });
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getHome(String homeId) async {
    final res = await _dio.get('/homes/$homeId');
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> updateChecklist(
    String homeId,
    Map<String, bool> items,
  ) async {
    final res = await _dio.put('/homes/$homeId/checklist', data: {
      'items': items,
    });
    return res.data as Map<String, dynamic>;
  }
}
