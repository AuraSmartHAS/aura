import 'package:flutter/foundation.dart';

import 'package:aura/core/errors/result.dart';
import 'package:aura/core/network/error_mapper.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import 'package:aura/core/session/user_role.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDataSource, this._tokenStore, this._session);

  final AuthRemoteDataSource _remoteDataSource;
  final TokenStore _tokenStore;
  final AuthSession _session;

  @override
  Future<Result<UserEntity>> login(String email, String password) async {
    try {
      final creds = await _remoteDataSource.login(email, password);
      final role = UserRole.fromString(creds.role);
      debugPrint(
        '[AURA-AUTH] login ok email=$email rawRole="${creds.role}" '
        'parsedRole=$role isPatient=${role.isPatient}',
      );
      await _tokenStore.saveSession(
        accessToken: creds.token,
        refreshToken: creds.refreshToken,
        role: creds.role,
      );
      await _session.onLoggedIn(role);
      return Success(UserEntity(role: role, email: email));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<UserEntity>> signup(
    String email,
    String password,
    String role,
  ) async {
    try {
      debugPrint('[AURA-AUTH] signup requested email=$email role="$role"');
      await _remoteDataSource.signup(email, password, role);
      // Login right after to obtain token + refreshToken + canonical role.
      return login(email, password);
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<void>> logout() async {
    await _session.onLoggedOut();
    return const Success(null);
  }
}
