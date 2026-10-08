import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../network/api_client.dart';
import 'notification_ack.dart';
import 'push_payload.dart';

/// Um aviso recebido, já sem o tipo do SDK: título, corpo e o `data` do deep link.
class PushMessage {
  const PushMessage({
    this.title,
    this.body,
    this.data = const {},
    this.systemDrawn = false,
  });

  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  /// Veio com o bloco `notification`: fora do primeiro plano o próprio Android
  /// desenha. O SOS vem só com dados e depende do app para aparecer.
  final bool systemDrawn;

  /// O SOS chega só com dados (para o aviso poder ter o botão "Estou indo"):
  /// título e texto vêm então de `data.title` e `data.message`.
  factory PushMessage.fromRemote(RemoteMessage message) => PushMessage(
        title: message.notification?.title ?? message.data['title'] as String?,
        body: message.notification?.body ?? message.data['message'] as String?,
        data: Map<String, dynamic>.from(message.data),
        systemDrawn: message.notification != null,
      );
}

/// O pedaço do Firebase Messaging que o `NotificationService` usa. Existe para
/// o teste trocar o SDK por um falso sem plataforma nenhuma.
abstract class PushMessaging {
  /// Pede a permissão de aviso (no Android 13+ é o prompt de runtime do
  /// POST_NOTIFICATIONS). Devolve se o app pode exibir avisos.
  Future<bool> requestPermission();

  Future<String?> getToken();

  /// Invalida o token deste aparelho no FCM: nem um envio atrasado chega mais.
  Future<void> deleteToken();

  Stream<String> get onTokenRefresh;

  /// Aviso que chegou com o app aberto (o sistema não o exibe sozinho).
  Stream<PushMessage> get onMessage;

  /// Toque num aviso com o app em segundo plano.
  Stream<PushMessage> get onMessageOpenedApp;

  /// Toque num aviso que abriu o app encerrado.
  Future<PushMessage?> getInitialMessage();
}

class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging([FirebaseMessaging? messaging])
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get onMessage =>
      FirebaseMessaging.onMessage.map(PushMessage.fromRemote);

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(PushMessage.fromRemote);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PushMessage.fromRemote(message);
  }
}

/// Registro do aparelho no backend (`/notifications/register-token`).
abstract class PushTokenApi {
  Future<void> register(String token);

  /// Desregistra no logout. Com [token], o servidor só apaga se ele ainda for o
  /// registrado — o logout atrasado de um aparelho antigo não desliga o atual.
  Future<void> unregister(String? token);
}

class DioPushTokenApi implements PushTokenApi {
  DioPushTokenApi(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> register(String token) => _apiClient.dio.post(
        '/notifications/register-token',
        data: {'fcmToken': token},
      );

  @override
  Future<void> unregister(String? token) => _apiClient.dio.delete(
        '/notifications/register-token',
        data: token == null ? null : {'fcmToken': token},
      );
}

/// Avisos locais: os canais Android e a exibição do aviso que chega com o app
/// aberto — o FCM só desenha sozinho com o app em segundo plano ou encerrado.
abstract class LocalNotifier {
  /// Cria os canais e passa a entregar em [onTap] o `data` do aviso tocado.
  Future<void> init(void Function(Map<String, dynamic> data) onTap);

  Future<void> show(PushMessage message);

  /// `data` do aviso local que abriu o app encerrado, se foi isso.
  Future<Map<String, dynamic>?> launchData();
}

class FlutterLocalNotifier implements LocalNotifier {
  FlutterLocalNotifier([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _sos = AndroidNotificationChannel(
    PushChannels.sosId,
    PushChannels.sosName,
    description: PushChannels.sosDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const _geral = AndroidNotificationChannel(
    PushChannels.geralId,
    PushChannels.geralName,
    description: PushChannels.geralDescription,
    importance: Importance.high,
  );

  @override
  Future<void> init(void Function(Map<String, dynamic> data) onTap) async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_aura'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final data = decodePushPayload(response.payload);
        if (data != null) onTap(data);
      },
      // "Estou indo" no aviso: sem abrir o app, num isolate próprio
      onDidReceiveBackgroundNotificationResponse: onNotificationActionInBackground,
    );
    await createChannels(_plugin);
  }

  /// Também usada pelo handler de segundo plano, que roda noutro isolate.
  static Future<void> createChannels(
      FlutterLocalNotificationsPlugin plugin) async {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_sos);
    await android?.createNotificationChannel(_geral);
  }

  @override
  Future<void> show(PushMessage message) => showWith(_plugin, message);

  static Future<void> showWith(
      FlutterLocalNotificationsPlugin plugin, PushMessage message) {
    final sos = isSos(message.data['kind'] as String?);
    final channel = sos ? _sos : _geral;
    return plugin.show(
      pushNotificationId(message.data),
      message.title ?? 'AURA',
      message.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: sos ? Priority.max : Priority.high,
          category: sos ? AndroidNotificationCategory.alarm : null,
          icon: '@drawable/ic_stat_aura',
          actions: offersAck(message.data)
              ? const [
                  AndroidNotificationAction(
                    ackActionId,
                    'Estou indo',
                    // confirma sem abrir o app; o aviso é trocado pelo resultado
                    showsUserInterface: false,
                    cancelNotification: true,
                  ),
                ]
              : null,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  @override
  Future<Map<String, dynamic>?> launchData() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return decodePushPayload(details.notificationResponse?.payload);
  }
}
