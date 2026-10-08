import 'dart:convert';
import 'dart:typed_data';

import 'package:aura/core/network/auth_interceptor.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import 'package:aura/core/session/user_role.dart';
import 'package:aura/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:aura/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Servidor dublado que responde sempre o mesmo erro.
class _FakeBackend implements HttpClientAdapter {
  _FakeBackend(this.status, this.code);

  final int status;
  final String code;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode({
          'error': {'code': code, 'message': 'x'},
        }),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// O logout do repositório não fala com o servidor.
class _UnusedRemote implements AuthRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// #14 — logout forçado deixa um aviso de uma vez só para a tela de login.
void main() {
  late TokenStore store;
  late AuthSession session;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    store = TokenStore(const FlutterSecureStorage());
    // Refresh token vazio: o refresh falha sem tocar a rede.
    await store.saveSession(
      accessToken: 'jwt',
      refreshToken: '',
      role: 'paciente',
    );
    session = AuthSession(store);
    await session.bootstrap();
  });

  Dio dioWith(_FakeBackend backend) {
    final dio = Dio(BaseOptions(baseUrl: 'http://aura.test'))
      ..httpClientAdapter = backend;
    dio.interceptors.add(
      AuthInterceptor(
        tokenStore: store,
        session: session,
        baseUrl: 'http://aura.test',
      ),
    );
    return dio;
  }

  group('AuthSession', () {
    test('primeiro uso: não há aviso', () {
      final fresh = AuthSession(store);
      expect(fresh.hasSessionExpiredNotice, isFalse);
      expect(fresh.consumeSessionExpiredNotice(), isFalse);
    });

    test('logout forçado marca o aviso, e consumir o apaga', () async {
      await session.onLoggedOut(forced: true);

      expect(session.isAuthenticated, isFalse);
      expect(session.hasSessionExpiredNotice, isTrue);
      expect(session.consumeSessionExpiredNotice(), isTrue);
      expect(session.consumeSessionExpiredNotice(), isFalse);
    });

    test('logout voluntário não marca o aviso', () async {
      await session.onLoggedOut();

      expect(session.hasSessionExpiredNotice, isFalse);
    });

    test('segundo logout forçado sem sessão não reacende o aviso', () async {
      await session.onLoggedOut(forced: true);
      session.consumeSessionExpiredNotice();

      await session.onLoggedOut(forced: true);

      expect(session.hasSessionExpiredNotice, isFalse);
    });

    test('entrar de novo apaga um aviso pendente', () async {
      await session.onLoggedOut(forced: true);

      await session.onLoggedIn(UserRole.paciente);

      expect(session.hasSessionExpiredNotice, isFalse);
    });
  });

  group('AuthInterceptor', () {
    test('refresh falho após TOKEN_EXPIRED é logout forçado com aviso',
        () async {
      final dio = dioWith(_FakeBackend(401, 'TOKEN_EXPIRED'));

      await expectLater(dio.get('/auth/me'), throwsA(isA<DioException>()));

      expect(session.isAuthenticated, isFalse);
      expect(session.hasSessionExpiredNotice, isTrue);
    });

    test('senha errada (401 sem TOKEN_EXPIRED) não desloga nem avisa',
        () async {
      final dio = dioWith(_FakeBackend(401, 'INVALID_CREDENTIALS'));

      await expectLater(
        dio.post('/auth/login'),
        throwsA(isA<DioException>()),
      );

      expect(session.isAuthenticated, isTrue);
      expect(session.hasSessionExpiredNotice, isFalse);
    });
  });

  test('"Sair da conta" (logout do repositório) não deixa aviso', () async {
    await AuthRepositoryImpl(_UnusedRemote(), store, session).logout();

    expect(session.isAuthenticated, isFalse);
    expect(session.hasSessionExpiredNotice, isFalse);
  });
}
