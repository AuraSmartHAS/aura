import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<Result<UserEntity>> login(String email, String password) async {
    try {
      final userModel = await _remoteDataSource.login(email, password);
      return Success(userModel.toEntity());
    } catch (e) {
      return Failure(
        AppFailure.unexpected(message: e.toString()),
      );
    }
  }

  @override
  Future<Result<UserEntity>> signup(String email, String password) async {
    try {
      final userModel = await _remoteDataSource.signup(email, password);
      return Success(userModel.toEntity());
    } catch (e) {
      return Failure(
        AppFailure.unexpected(message: e.toString()),
      );
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await _remoteDataSource.logout();
      return const Success(null);
    } catch (e) {
      return Failure(
        AppFailure.unexpected(message: e.toString()),
      );
    }
  }

  @override
  Future<Result<UserEntity?>> getCurrentUser() async {
    try {
      final userModel = await _remoteDataSource.getCurrentUser();
      return Success(userModel?.toEntity());
    } catch (e) {
      return Failure(
        AppFailure.unexpected(message: e.toString()),
      );
    }
  }
}
