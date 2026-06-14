import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';

abstract class ConsentRemoteDataSource {
  Future<void> accept(String version);
}

class ConsentRemoteDataSourceImpl implements ConsentRemoteDataSource {
  ConsentRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  @override
  Future<void> accept(String version) async {
    await _dio.post('/consent', data: {'version': version});
  }
}
