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
      await _adoptExistingHome();
      await _adoptServerProfile();
      await _session.onLoggedIn(role);
      return Success(UserEntity(role: role, email: email));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  /// O `homeId` vive só no aparelho, mas a casa vive no backend. Num aparelho
  /// novo (ou depois de reinstalar) o armazenamento local está vazio: a cuidadora
  /// cairia no onboarding, duplicando o cadastro, e a Maria ficaria com o SOS sem
  /// saber a quem avisar (ele usa a casa pareada ao aparelho). Aqui adotamos a
  /// casa que a API já conhece, para qualquer papel. Falha de rede não derruba o
  /// login: sem o id, o fluxo cai no onboarding como antes.
  Future<void> _adoptExistingHome() async {
    if (await _tokenStore.homeId != null) return;
    try {
      final homeId = await _remoteDataSource.firstHomeId();
      if (homeId != null) await _tokenStore.saveHomeId(homeId);
    } catch (e) {
      debugPrint('[AURA-AUTH] não consegui listar as casas: $e');
    }
  }

  /// O aceite dos termos é fato do servidor (`POST /consent` grava, `GET
  /// /auth/me` devolve). A flag local é só cache para o guard de rotas: a cada
  /// login ela é refeita a partir do servidor, então outro aparelho não pede o
  /// aceite de novo e um servidor sem o registro volta a pedir. Sem resposta
  /// (rede), a flag local fica como estava.
  ///
  /// A mesma resposta traz o nome que a saudação usa. O nome anterior é
  /// apagado antes da chamada: sem resposta, a tela cumprimenta sem nome em vez
  /// de chamar este usuário pelo nome de outro.
  Future<void> _adoptServerProfile() async {
    await _tokenStore.saveUserName(null);
    try {
      final me = await _remoteDataSource.me();
      if (me.consentAccepted) {
        await _tokenStore.setConsentAccepted();
      } else {
        await _tokenStore.clearConsentAccepted();
      }
      await _tokenStore.saveUserName(me.name);
    } catch (e) {
      debugPrint('[AURA-AUTH] não consegui consultar /auth/me no servidor: $e');
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
