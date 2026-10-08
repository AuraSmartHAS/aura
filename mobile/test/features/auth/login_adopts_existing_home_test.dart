import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import 'package:aura/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:aura/features/auth/data/models/user_model.dart';
import 'package:aura/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRemote implements AuthRemoteDataSource {
  _FakeRemote({
    this.role = 'cuidadora',
    this.homeId,
    this.homesFail = false,
    this.consent = false,
    this.consentFail = false,
    this.name,
  });

  final String role;
  final String? homeId;
  final bool homesFail;
  final bool consent;
  final bool consentFail;
  final String? name;
  int homesCalls = 0;
  int meCalls = 0;

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

  @override
  Future<MeModel> me() async {
    meCalls++;
    if (consentFail) throw Exception('sem rede');
    return MeModel(consentAccepted: consent, name: name);
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
    final result = await repo(_FakeRemote(homesFail: true)).login('a@a', 'x');

    expect(result, isA<Success>());
    expect(session.isAuthenticated, isTrue);
    expect(session.homeId, isNull);
  });

  test('homeId local existente não é sobrescrito nem consulta a API', () async {
    await store.saveHomeId('local');
    final remote = _FakeRemote(homeId: 'backend');

    await repo(remote).login('a@a', 'x');

    expect(session.homeId, 'local');
    expect(remote.homesCalls, 0);
  });

  test('paciente também adota a casa: é ela que o SOS do aparelho avisa',
      () async {
    final remote = _FakeRemote(role: 'paciente', homeId: 'casa-1');

    await repo(remote).login('m@a', 'x');

    expect(remote.homesCalls, 1);
    expect(session.homeId, 'casa-1');
    expect(await store.pairedHomeId, 'casa-1');
  });

  group('aceite dos termos vem do servidor', () {
    test('servidor com aceite: o aparelho novo não pede de novo', () async {
      final result = await repo(_FakeRemote(consent: true)).login('a@a', 'x');

      expect(result, isA<Success>());
      expect(session.consentAccepted, isTrue);
      expect(await store.consentAccepted, isTrue);
    });

    test('servidor sem aceite: o app volta a pedir, mesmo com flag local',
        () async {
      await store.setConsentAccepted();

      await repo(_FakeRemote(consent: false)).login('a@a', 'x');

      expect(session.consentAccepted, isFalse);
      expect(await store.consentAccepted, isFalse);
    });

    test('sem resposta do servidor, a flag local fica como estava', () async {
      await store.setConsentAccepted();

      final result =
          await repo(_FakeRemote(consentFail: true)).login('a@a', 'x');

      expect(result, isA<Success>());
      expect(session.consentAccepted, isTrue);
    });
  });

  group('nome da saudação vem do mesmo GET /auth/me', () {
    test('login guarda o nome e a sessão expõe só o primeiro', () async {
      final remote = _FakeRemote(name: 'Beatriz Teste');

      await repo(remote).login('b@a', 'x');

      expect(remote.meCalls, 1, reason: 'aceite e nome saem da mesma chamada');
      expect(await store.userName, 'Beatriz Teste');
      expect(session.userFirstName, 'Beatriz');
    });

    test('nome do seed com o papel entre parênteses vira só "Ana"', () async {
      await repo(_FakeRemote(name: 'Ana (cuidadora)')).login('a@a', 'x');

      expect(session.userFirstName, 'Ana');
    });

    test('conta sem nome no servidor fica sem nome (não vira "Ana")', () async {
      await repo(_FakeRemote(name: '')).login('n@a', 'x');

      expect(session.userFirstName, isNull);
    });

    test('sem resposta do /auth/me o nome de quem saiu não sobra', () async {
      await store.saveUserName('Ana (cuidadora)');

      final result =
          await repo(_FakeRemote(consentFail: true)).login('b@a', 'x');

      expect(result, isA<Success>());
      expect(await store.userName, isNull);
      expect(session.userFirstName, isNull);
    });

    test('bootstrap recupera o nome guardado ao reabrir o app', () async {
      await repo(_FakeRemote(name: 'Beatriz Teste')).login('b@a', 'x');

      final reopened = AuthSession(store);
      await reopened.bootstrap();

      expect(reopened.userFirstName, 'Beatriz');
    });

    test('logout limpa o nome', () async {
      final r = repo(_FakeRemote(name: 'Beatriz Teste'));
      await r.login('b@a', 'x');

      await r.logout();

      expect(session.userFirstName, isNull);
      expect(await store.userName, isNull);
    });
  });
}
