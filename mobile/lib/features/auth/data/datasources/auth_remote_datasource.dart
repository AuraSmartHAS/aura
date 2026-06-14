import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthCredentialsModel> login(String email, String password);
  Future<void> signup(String email, String password, String role);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  @override
  Future<AuthCredentialsModel> login(String email, String password) async {
    final res = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthCredentialsModel.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<void> signup(String email, String password, String role) async {
    await _dio.post(
      '/auth/signup',
      data: {'email': email, 'password': password, 'role': role},
    );
  }
}
