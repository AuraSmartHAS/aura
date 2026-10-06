import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import 'package:aura/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:aura/features/auth/data/models/user_model.dart';
import 'package:aura/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRemote implements AuthRemoteDataSource {
  _FakeRemote({this.role = 'cuidadora', this.homeId, this.homesFail = false});

  final String role;
  final String? homeId;
  final bool homesFail;
  int homesCalls = 0;

  @override
  Future<AuthCredentialsModel> login(String email, String password) async =>
      AuthCredentialsModel(token: 't', refreshToken: 'r', role: role);

  @override
  Future<void> signup(String email, String password, String role) async {}

  @override
  Future<String?> firstHomeId() async {
    homesCalls++;
    if (homesFail) throw Exception('sem rede');
    return homeId;
  }
}

void main() {
  late TokenStore store;
  late AuthSession session;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    store = TokenStore(const FlutterSecureStorage());
    session = AuthSession(store);
  });

  AuthRepositoryImpl repo(_FakeRemote remote) =>
      AuthRepositoryImpl(remote, store, session);

  test('cuidadora com casa no backend entra já com o homeId', () async {
    final result = await repo(_FakeRemote(homeId: 'casa-1')).login('a@a', 'x');

    expect(result, isA<Success>());
    expect(session.homeId, 'casa-1');
    expect(await store.homeId, 'casa-1');
  });

  test('cuidadora sem casa no backend continua sem homeId (onboarding)',
      () async {
    await repo(_FakeRemote()).login('a@a', 'x');

    expect(session.homeId, isNull);
  });

  test('falha ao listar casas não derruba o login', () async {
    final result =
        await repo(_FakeRemote(homesFail: true)).login('a@a', 'x');

    expect(result, isA<Success>());
    expect(session.isAuthenticated, isTrue);
    expect(session.homeId, isNull);
  });

  test('homeId local existente não é sobrescrito nem consulta a API',
      () async {
    await store.saveHomeId('local');
    final remote = _FakeRemote(homeId: 'backend');

    await repo(remote).login('a@a', 'x');

    expect(session.homeId, 'local');
    expect(remote.homesCalls, 0);
  });

  test('paciente não consulta as casas', () async {
    final remote = _FakeRemote(role: 'paciente', homeId: 'casa-1');

    await repo(remote).login('m@a', 'x');

    expect(remote.homesCalls, 0);
    expect(session.homeId, isNull);
  });
}
