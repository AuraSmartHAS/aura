import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../session/auth_session.dart';
import '../session/token_store.dart';
import 'push_payload.dart';

/// Id da ação "Estou indo" no aviso de SOS (a mesma do RN e do `categoryId`
/// que o backend manda, `aura_sos_ack`).
const ackActionId = 'ack';

/// O toque em "Estou indo" no aviso. O plugin entrega a ação sem interface
/// sempre aqui, num isolate de segundo plano — com o app aberto, em segundo
/// plano ou encerrado. Precisa ser top-level e marcada como ponto de entrada.
@pragma('vm:entry-point')
void onNotificationActionInBackground(NotificationResponse response) {
  if (response.actionId != ackActionId) return;
  final data = decodePushPayload(response.payload);
  if (data == null) return;
  // isolate novo: sem binding, sem .env, sem service locator — tudo do zero
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.load().then((_) {
    final store = TokenStore(const FlutterSecureStorage());
    final dio = ApiClient(tokenStore: store, session: AuthSession(store)).dio;
    return acknowledgeFromNotification(
      data,
      ack: (id) => dio.post('/emergencies/$id/ack'),
      notify: _replaceSosNotification,
    );
  }).catchError((Object e) {
    debugPrint('"Estou indo" pelo aviso falhou antes de chegar ao servidor: $e');
    return false;
  });
}

/// Resultado do "Estou indo" para quem tocou: o aviso de SOS é trocado por um
/// que diz o que aconteceu, no mesmo id (o original some, sem tocar de novo).
typedef AckNotifier = Future<void> Function(
    Map<String, dynamic> data, bool acknowledged);

/// Confirma o SOS do aviso. Devolve se o servidor aceitou.
///
/// Falha não é silenciosa: o aviso volta dizendo que não deu certo, com o
/// toque abrindo a tela de socorro — onde o botão e o "Ligar 192" estão.
/// Visível para teste.
Future<bool> acknowledgeFromNotification(
  Map<String, dynamic> data, {
  required Future<void> Function(String emergencyId) ack,
  required AckNotifier notify,
}) async {
  final emergencyId = data['emergencyId'];
  if (emergencyId is! String || emergencyId.isEmpty) return false;
  var ok = false;
  try {
    await ack(emergencyId);
    ok = true;
  } catch (e) {
    debugPrint('"Estou indo" pelo aviso recusado: $e');
  }
  try {
    await notify(data, ok);
  } catch (e) {
    debugPrint('Aviso de resultado do "Estou indo" não exibido: $e');
  }
  return ok;
}

Future<void> _replaceSosNotification(
    Map<String, dynamic> data, bool acknowledged) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@drawable/ic_stat_aura'),
  ));
  await plugin.show(
    pushNotificationId(data),
    acknowledged ? 'AURA · Você está indo' : 'AURA · Não consegui confirmar',
    acknowledged
        ? 'Avisamos que você está a caminho. Toque para ver o endereço.'
        : 'Toque para abrir o pedido de ajuda e confirmar ou ligar.',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        PushChannels.geralId,
        PushChannels.geralName,
        channelDescription: PushChannels.geralDescription,
        icon: '@drawable/ic_stat_aura',
      ),
    ),
    // sem a categoria: o aviso de resultado não oferece o botão de novo
    payload: jsonEncode({...data}..remove('categoryId')),
  );
}

/// `data` do aviso local de volta ao mapa. Nulo quando ilegível.
Map<String, dynamic>? decodePushPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    return Map<String, dynamic>.from(jsonDecode(payload) as Map);
  } catch (e) {
    debugPrint('Payload de aviso local ilegível: $e');
    return null;
  }
}
