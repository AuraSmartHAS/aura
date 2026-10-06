import 'dart:convert';
import 'dart:typed_data';

import 'package:aura/core/errors/result.dart';
import 'package:aura/core/network/api_client.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import 'package:aura/features/home/data/datasources/conversation_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Servidor dublado: devolve [status]/[body] e guarda o que o app pediu.
class _FakeBackend implements HttpClientAdapter {
  _FakeBackend(this.status, this.body);

  final int status;
  final Map<String, dynamic> body;
  RequestOptions? seen;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late ConversationRemoteDataSourceImpl dataSource;
  late ApiClient client;

  setUp(() async {
    dotenv.testLoad(fileInput: 'BACKEND_BASE_URL=http://aura.test');
    FlutterSecureStorage.setMockInitialValues({});
    final store = TokenStore(const FlutterSecureStorage());
    await store.saveSession(
      accessToken: 'jwt-da-maria',
      refreshToken: 'r',
      role: 'paciente',
    );
    client = ApiClient(tokenStore: store, session: AuthSession(store));
    dataSource = ConversationRemoteDataSourceImpl(client);
  });

  test('busca o token em GET /voice/token com o JWT da sessão', () async {
    final backend = _FakeBackend(200, {'token': 'tok-123'});
    client.dio.httpClientAdapter = backend;

    final result = await dataSource.fetchToken();

    expect(result, isA<Success<String>>());
    expect((result as Success<String>).data, 'tok-123');
    expect(backend.seen!.path, '/voice/token');
    expect(backend.seen!.uri.host, 'aura.test');
    expect(backend.seen!.headers['Authorization'], 'Bearer jwt-da-maria');
  });

  test('voz não configurada no servidor (503) vira falha do token', () async {
    client.dio.httpClientAdapter = _FakeBackend(503, {
      'error': {'code': 'VOICE_NOT_CONFIGURED', 'message': 'sem voz'},
    });

    final result = await dataSource.fetchToken();

    expect(result, isA<Failure<String>>());
    expect('${(result as Failure<String>).failure}', contains('fetch token'));
  });

  test('resposta sem token é falha, não token vazio', () async {
    client.dio.httpClientAdapter = _FakeBackend(200, {});

    final result = await dataSource.fetchToken();

    expect(result, isA<Failure<String>>());
  });
}
