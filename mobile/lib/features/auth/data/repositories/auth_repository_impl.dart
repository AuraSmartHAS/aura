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
      if (!role.isPatient) await _adoptExistingHome();
      await _session.onLoggedIn(role);
      return Success(UserEntity(role: role, email: email));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  /// O `homeId` vive só no aparelho, mas a casa vive no backend. Num aparelho
  /// novo (ou depois de reinstalar) o armazenamento local está vazio e o app
  /// mandaria quem já tem casa para o onboarding, duplicando o cadastro. Aqui
  /// adotamos a casa que a API já conhece. Falha de rede não derruba o login:
  /// sem o id, o fluxo cai no onboarding como antes.
  Future<void> _adoptExistingHome() async {
    if (await _tokenStore.homeId != null) return;
    try {
      final homeId = await _remoteDataSource.firstHomeId();
      if (homeId != null) await _tokenStore.saveHomeId(homeId);
    } catch (e) {
      debugPrint('[AURA-AUTH] não consegui listar as casas: $e');
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
      // `await` garante que uma falha do login caia neste catch (e vire uma
      // mensagem amigável), em vez de escapar como erro não tratado.
      return await login(email, password);
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
