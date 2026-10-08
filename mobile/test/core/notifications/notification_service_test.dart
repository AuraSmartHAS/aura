import 'dart:async';

import 'package:aura/core/notifications/notification_ack.dart';
import 'package:aura/core/notifications/notification_service.dart';
import 'package:aura/core/notifications/push_payload.dart';
import 'package:aura/core/notifications/push_ports.dart';
import 'package:aura/core/router/app_routes.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import 'package:aura/core/session/user_role.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Firebase Messaging dublado: o teste empurra token novo, aviso em primeiro
/// plano e toque, sem plataforma nenhuma.
class _FakeMessaging implements PushMessaging {
  String? token = 'token-1';
  bool permission = true;
  PushMessage? initial;
  int deleted = 0;
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();

  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<String?> getToken() async => token;
  @override
  Future<void> deleteToken() async {
    deleted++;
    token = null;
  }

  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Stream<PushMessage> get onMessage => foreground.stream;
  @override
  Stream<PushMessage> get onMessageOpenedApp => opened.stream;
  @override
  Future<PushMessage?> getInitialMessage() async => initial;

  Future<void> close() async {
    await refresh.close();
    await foreground.close();
    await opened.close();
  }
}

class _FakeTokenApi implements PushTokenApi {
  final registered = <String>[];
  final unregistered = <String?>[];
  bool failUnregister = false;

  @override
  Future<void> register(String token) async => registered.add(token);
  @override
  Future<void> unregister(String? token) async {
    unregistered.add(token);
    if (failUnregister) throw Exception('sem rede');
  }
}

class _FakeLocal implements LocalNotifier {
  void Function(Map<String, dynamic>)? onTap;
  final shown = <PushMessage>[];
  Map<String, dynamic>? launch;

  @override
  Future<void> init(void Function(Map<String, dynamic>) onTap) async =>
      this.onTap = onTap;
  @override
  Future<void> show(PushMessage message) async => shown.add(message);
  @override
  Future<Map<String, dynamic>?> launchData() async => launch;
}

const _sos = {
  'kind': 'sos',
  'homeId': 'home-1',
  'emergencyId': 'em-1',
  'state': 'dispatched',
  'action': 'ack',
  'lat': '-23.56',
  'lng': '-46.65',
  'address': 'Av. Paulista, 1000',
};

void main() {
  late TokenStore store;
  late AuthSession session;
  late _FakeMessaging messaging;
  late _FakeTokenApi api;
  late _FakeLocal local;
  late List<String> navigated;
  late bool foreground;
  late NotificationService service;

  Future<void> logIn({String role = 'cuidadora', bool consent = true}) async {
    await store.saveSession(accessToken: 'jwt', refreshToken: 'r', role: role);
    if (consent) await store.setConsentAccepted();
    await session.onLoggedIn(UserRole.fromString(role));
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    store = TokenStore(const FlutterSecureStorage());
    session = AuthSession(store);
    messaging = _FakeMessaging();
    api = _FakeTokenApi();
    local = _FakeLocal();
    navigated = [];
    foreground = true;
    service = NotificationService(
      tokenApi: api,
      session: session,
      messaging: messaging,
      localNotifier: local,
      navigate: navigated.add,
      isForeground: () => foreground,
    );
  });

  tearDown(() async {
    await service.dispose();
    await messaging.close();
  });

  group('deep link', () {
    test('SOS leva à tela de socorro com o endereço do aviso', () {
      final link = deepLinkFor(_sos);
      final uri = Uri.parse(link!);
      expect(uri.path, '/emergencies/em-1');
      expect(uri.queryParameters['address'], 'Av. Paulista, 1000');
      expect(uri.queryParameters['lat'], '-23.56');
      expect(uri.queryParameters['homeId'], 'home-1');
    });

    test('pedido, recomendação e cancelamento de SOS', () {
      expect(deepLinkFor({'kind': 'order', 'orderId': 'o-1'}),
          AppRoutes.orderDetail('o-1'));
      expect(deepLinkFor({'kind': 'recommendation', 'recommendationId': 'r-1'}),
          AppRoutes.careChain);
      expect(deepLinkFor({'kind': 'sos_cancelled', 'emergencyId': 'em-1'}),
          AppRoutes.dashboard);
      expect(deepLinkFor({'kind': 'order'}), isNull);
    });

    test('canal do SOS separado do canal geral', () {
      expect(PushChannels.forKind('sos'), PushChannels.sosId);
      expect(PushChannels.forKind('sos_escalated'), PushChannels.sosId);
      expect(PushChannels.forKind('order'), PushChannels.geralId);
    });

    test('toque sem sessão fica guardado e só sai depois do login', () async {
      await service.init();

      messaging.opened.add(const PushMessage(data: _sos));
      await Future<void>.delayed(Duration.zero);

      expect(navigated, isEmpty, reason: 'não há sessão: navegar agora cairia no login');
      expect(service.pendingDeepLink, startsWith('/emergencies/em-1'));

      await logIn();
      final link = service.takePendingDeepLink();
      expect(link, startsWith('/emergencies/em-1'));
      expect(service.takePendingDeepLink(), isNull, reason: 'uma vez só');
    });

    test('toque que abriu o app encerrado com sessão viva navega direto', () async {
      await logIn();
      messaging.initial = const PushMessage(data: {'kind': 'order', 'orderId': 'o-9'});

      await service.init();

      expect(navigated, [AppRoutes.orderDetail('o-9')]);
      expect(service.pendingDeepLink, isNull);
    });

    test('a paciente não herda o destino da tela de quem cuida', () async {
      await service.init();
      messaging.opened.add(const PushMessage(data: _sos));
      await Future<void>.delayed(Duration.zero);

      await logIn(role: 'paciente');
      expect(service.takePendingDeepLink(), isNull);
    });

    test('sem consentimento o destino espera o gate LGPD', () async {
      await logIn(consent: false);
      await service.init();

      local.onTap!({'kind': 'order', 'orderId': 'o-2'});

      expect(navigated, isEmpty);
      expect(service.pendingDeepLink, AppRoutes.orderDetail('o-2'));
    });
  });

  group('"Estou indo" no aviso', () {
    test('SOS em aberto oferece o botão; retração e pedido, não', () {
      expect(offersAck({..._sos, 'categoryId': sosAckCategory}), isTrue);
      expect(offersAck(_sos), isTrue);
      expect(offersAck({'kind': 'sos_cancelled', 'emergencyId': 'em-1', 'action': 'none'}),
          isFalse);
      expect(offersAck({'kind': 'order', 'orderId': 'o-1'}), isFalse);
    });

    test('o id do aviso é o mesmo para o mesmo SOS (o resultado substitui o original)', () {
      expect(pushNotificationId(_sos), pushNotificationId({'emergencyId': 'em-1'}));
      expect(pushNotificationId(_sos), isNot(pushNotificationId({'emergencyId': 'em-2'})));
      expect(pushNotificationId(_sos), greaterThanOrEqualTo(0));
    });

    test('confirma no servidor e troca o aviso pelo resultado', () async {
      final acked = <String>[];
      final results = <bool>[];

      final ok = await acknowledgeFromNotification(
        _sos,
        ack: (id) async => acked.add(id),
        notify: (data, acknowledged) async => results.add(acknowledged),
      );

      expect(ok, isTrue);
      expect(acked, ['em-1']);
      expect(results, [true]);
    });

    test('recusa do servidor não some calada: o aviso diz que não deu', () async {
      final results = <bool>[];

      final ok = await acknowledgeFromNotification(
        _sos,
        ack: (_) async => throw Exception('401'),
        notify: (data, acknowledged) async => results.add(acknowledged),
      );

      expect(ok, isFalse);
      expect(results, [false]);
    });

    test('aviso sem emergência não chama o servidor', () async {
      var called = false;
      final ok = await acknowledgeFromNotification(
        {'kind': 'order'},
        ack: (_) async => called = true,
        notify: (_, __) async {},
      );
      expect(ok, isFalse);
      expect(called, isFalse);
    });
  });

  group('primeiro plano', () {
    test('aviso com o app aberto vira aviso local, e o toque nele navega', () async {
      await logIn();
      await service.init();

      messaging.foreground.add(const PushMessage(
          title: 'AURA · Pedido de ajuda', body: 'A Maria pediu ajuda agora.', data: _sos));
      await Future<void>.delayed(Duration.zero);

      expect(local.shown.single.data['kind'], 'sos');
      local.onTap!(local.shown.single.data);
      expect(navigated.single, startsWith('/emergencies/em-1'));
    });
  });

  group('segundo plano', () {
    test('na transição para o segundo plano o app não desenha de novo o aviso do sistema',
        () async {
      await logIn();
      await service.init();
      foreground = false;

      messaging.foreground.add(const PushMessage(
          data: {'kind': 'order', 'orderId': 'o-1'}, systemDrawn: true));
      await Future<void>.delayed(Duration.zero);

      expect(local.shown, isEmpty);
    });

    test('o SOS só de dados é desenhado mesmo na transição: não há cópia do sistema',
        () async {
      await logIn();
      await service.init();
      foreground = false;

      messaging.foreground.add(const PushMessage(data: _sos));
      await Future<void>.delayed(Duration.zero);

      expect(local.shown.single.data['emergencyId'], 'em-1');
    });
  });

  group('ciclo de vida do token', () {
    test('registra no início com sessão, e não registra sem sessão', () async {
      await service.init();
      expect(api.registered, isEmpty);

      await logIn();
      await Future<void>.delayed(Duration.zero);
      expect(api.registered, ['token-1'], reason: 'o login registra o aparelho');
    });

    test('sem permissão não registra no início', () async {
      await logIn();
      messaging.permission = false;
      await service.init();
      expect(api.registered, isEmpty);
    });

    test('token trocado pelo FCM é registrado de novo', () async {
      await logIn();
      await service.init();
      api.registered.clear();

      messaging.refresh.add('token-2');
      await Future<void>.delayed(Duration.zero);

      expect(api.registered, ['token-2']);
    });

    test('token trocado sem sessão não vai ao servidor', () async {
      await service.init();
      messaging.refresh.add('token-2');
      await Future<void>.delayed(Duration.zero);
      expect(api.registered, isEmpty);
    });

    test('logout desregistra com o token do aparelho e invalida o token no FCM',
        () async {
      await logIn();
      await service.init();

      await service.unregister();

      expect(api.unregistered, ['token-1']);
      expect(messaging.deleted, 1);
    });

    test('sem rede no logout, o token ainda é invalidado no FCM', () async {
      await logIn();
      await service.init();
      api.failUnregister = true;

      await service.unregister();

      expect(messaging.deleted, 1);
    });
  });
}
