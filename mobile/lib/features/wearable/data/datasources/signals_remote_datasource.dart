import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';

/// Posts signals to the backend (`POST /signals`). Used by the wearable opt-in
/// to send `type=vitals source=wearable`.
abstract class SignalsRemoteDataSource {
  Future<void> postVitals(String homeId, Map<String, dynamic> value);
}

class SignalsRemoteDataSourceImpl implements SignalsRemoteDataSource {
  SignalsRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  @override
  Future<void> postVitals(String homeId, Map<String, dynamic> value) async {
    await _dio.post('/signals', data: {
      'homeId': homeId,
      'type': 'vitals',
      'source': 'wearable',
      'value': value,
    });
  }
}
