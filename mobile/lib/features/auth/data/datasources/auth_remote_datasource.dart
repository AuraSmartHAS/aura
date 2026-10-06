import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthCredentialsModel> login(String email, String password);
  Future<void> signup(String email, String password, String role);

  /// Id da primeira casa que o usuário já tem no backend (`GET /homes`), ou
  /// `null` quando ele ainda não cadastrou nenhuma.
  Future<String?> firstHomeId();
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

  @override
  Future<String?> firstHomeId() async {
    final res = await _dio.get('/homes');
    final homes = res.data as List<dynamic>;
    if (homes.isEmpty) return null;
    return (homes.first as Map<String, dynamic>)['id'] as String?;
  }
}
