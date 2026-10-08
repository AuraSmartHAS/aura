import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../router/app_router.dart';
import '../session/auth_session.dart';
import 'notification_ack.dart';
import 'push_payload.dart';
import 'push_ports.dart';

/// Aviso que chega com o app em segundo plano ou encerrado (outro isolate).
///
/// Aviso com `notification` o próprio sistema desenha, no canal que o backend
/// indicou — desenhar de novo aqui duplicaria. O aviso só de dados (o SOS, que
/// precisa do botão "Estou indo") é desenhado aqui, senão chegaria e ninguém
/// veria.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.notification != null) return;
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_aura'),
    ),
    onDidReceiveBackgroundNotificationResponse: onNotificationActionInBackground,
  );
  await FlutterLocalNotifier.createChannels(plugin);
  await FlutterLocalNotifier.showWith(plugin, PushMessage.fromRemote(message));
}

/// Push de ponta a ponta no app: permissão, ciclo de vida do token, exibição
/// com o app aberto e o deep link do toque.
///
/// **Deep link com sessão:** o toque pode chegar antes de haver sessão (app
/// encerrado, sessão expirada, tela de login). O destino fica guardado e só é
/// usado quando a sessão existe — quem o consome é o guard do router, no
/// momento em que a pessoa chegaria à tela inicial ([takePendingDeepLink]).
class NotificationService {
  NotificationService({
    required PushTokenApi tokenApi,
    required AuthSession session,
    PushMessaging? messaging,
    LocalNotifier? localNotifier,
    void Function(String location)? navigate,
    bool Function()? isForeground,
  })  : _tokenApi = tokenApi,
        _session = session,
        _messaging = messaging ?? FirebasePushMessaging(),
        _local = localNotifier ?? FlutterLocalNotifier(),
        _navigate = navigate ?? _goWhenFramed,
        _isForeground = isForeground ?? _resumed;

  final PushTokenApi _tokenApi;
  final AuthSession _session;
  final PushMessaging _messaging;
  final LocalNotifier _local;
  final void Function(String location) _navigate;
  final bool Function() _isForeground;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  String? _pendingDeepLink;
  bool _wasAuthenticated = false;

  /// Destino guardado à espera de sessão (visível para teste).
  @visibleForTesting
  String? get pendingDeepLink => _pendingDeepLink;

  Future<void> init() async {
    // login e cadastro passam pela sessão: é na virada para autenticado que o
    // aparelho é registrado, qualquer que seja a tela que fez o login
    _wasAuthenticated = _session.isAuthenticated;
    _session.addListener(_onSessionChanged);
    try {
      await _local.init(openFromData);
    } catch (e) {
      // sem canal local o push em segundo plano ainda chega; não derruba o resto
      debugPrint('Avisos locais indisponíveis: $e');
    }
    try {
      _subscriptions
        ..add(_messaging.onTokenRefresh.listen(_registerToken))
        ..add(_messaging.onMessage.listen(_showInForeground))
        ..add(_messaging.onMessageOpenedApp.listen((m) => openFromData(m.data)));

      // permissão concedida é um dos momentos de registrar: no Android 13+ o
      // token existe antes, mas sem permissão o aviso não aparece
      final allowed = await _messaging.requestPermission();
      if (allowed) await registerToken();

      final initial = await _messaging.getInitialMessage();
      if (initial != null) openFromData(initial.data);
      final launch = await _local.launchData();
      if (launch != null) openFromData(launch);
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  /// Registra o token deste aparelho no backend. Chamado no início do app, no
  /// login, quando a permissão é concedida e quando o FCM troca o token.
  Future<void> registerToken() async {
    if (!_session.isAuthenticated) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) await _tokenApi.register(token);
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  void _onSessionChanged() {
    final now = _session.isAuthenticated;
    if (now && !_wasAuthenticated) unawaited(registerToken());
    _wasAuthenticated = now;
  }

  Future<void> _registerToken(String token) async {
    if (!_session.isAuthenticated) return;
    try {
      await _tokenApi.register(token);
    } catch (e) {
      debugPrint('FCM token refresh registration failed: $e');
    }
  }

  /// Logout: o aparelho deixa de receber os avisos de quem saiu. Precisa rodar
  /// **antes** de apagar a sessão (o DELETE é autenticado). Melhor esforço nos
  /// dois passos: sem rede, apagar o token no FCM ainda corta o aviso, e o
  /// logout nunca fica preso esperando.
  Future<void> unregister() async {
    String? token;
    try {
      token = await _messaging.getToken();
    } catch (_) {}
    try {
      await _tokenApi.unregister(token).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('FCM token unregister failed: $e');
    }
    try {
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('FCM token delete failed: $e');
    }
    _pendingDeepLink = null;
  }

  /// Aviso que o sistema desenha só é desenhado aqui com o app de fato na
  /// frente: na transição para o segundo plano o FCM já desenhou o dele
  /// enquanto o `onMessage` ainda dispara, e saíam dois avisos para um envio
  /// (visto no Samsung). O SOS, só de dados, não tem cópia do sistema: é
  /// desenhado sempre, senão sumiria justamente nessa transição.
  Future<void> _showInForeground(PushMessage message) async {
    if (message.systemDrawn && !_isForeground()) return;
    try {
      await _local.show(message);
    } catch (e) {
      debugPrint('Aviso em primeiro plano não exibido: $e');
    }
  }

  /// O toque num aviso (FCM ou local). Com sessão pronta navega já; sem ela,
  /// guarda o destino para depois do login.
  void openFromData(Map<String, dynamic> data) {
    final location = deepLinkFor(data);
    if (location == null) return;
    if (!_session.isAuthenticated || !_session.consentAccepted) {
      _pendingDeepLink = location;
      return;
    }
    if (_session.role?.isPatient ?? false) return;
    _navigate(location);
  }

  /// Entrega o destino guardado, uma vez só. Quem chama é o guard do router,
  /// quando a pessoa já tem sessão e consentimento e iria para a tela inicial.
  /// A paciente não herda o destino: a tela de socorro e o pedido são de quem
  /// cuida — e o aviso tocado era endereçado a outra pessoa.
  String? takePendingDeepLink() {
    final location = _pendingDeepLink;
    _pendingDeepLink = null;
    if (location == null || (_session.role?.isPatient ?? false)) return null;
    return location;
  }

  @visibleForTesting
  Future<void> dispose() async {
    _session.removeListener(_onSessionChanged);
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
  }

  static bool _resumed() =>
      SchedulerBinding.instance.lifecycleState == AppLifecycleState.resumed;

  /// O toque pode chegar antes do primeiro quadro (app abrindo): a navegação
  /// espera o router estar montado, e o destino abre por cima da tela inicial.
  static void _goWhenFramed(String location) {
    SchedulerBinding.instance.addPostFrameCallback(
        (_) => AppRouter.openOverHome(location));
    SchedulerBinding.instance.scheduleFrame();
  }
}
