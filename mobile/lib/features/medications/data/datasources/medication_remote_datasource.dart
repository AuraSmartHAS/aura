import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';

/// Medication routes of aura-server. The server is the source of truth: what
/// the caregiver registers here feeds dose confirmation, adherence and the
/// stock-based refill.
abstract class MedicationRemoteDataSource {
  Future<List<dynamic>> getMedications(String homeId);
  Future<Map<String, dynamic>> create(String homeId, Map<String, dynamic> body);
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> body);
  Future<void> delete(String id);
  Future<Map<String, dynamic>> confirm(String id, {required bool taken});
}

class MedicationRemoteDataSourceImpl implements MedicationRemoteDataSource {
  MedicationRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  @override
  Future<List<dynamic>> getMedications(String homeId) async {
    final res = await _dio.get('/homes/$homeId/medications');
    return res.data as List<dynamic>;
  }

  @override
  Future<Map<String, dynamic>> create(
    String homeId,
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.post('/homes/$homeId/medications', data: body);
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.put('/medications/$id', data: body);
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<void> delete(String id) async {
    await _dio.delete('/medications/$id');
  }

  @override
  Future<Map<String, dynamic>> confirm(String id, {required bool taken}) async {
    final res =
        await _dio.post('/medications/$id/confirm', data: {'taken': taken});
    return res.data as Map<String, dynamic>;
  }
}
