import '../router/app_routes.dart';

/// Canais Android do AURA. Os ids são os mesmos que o backend põe em
/// `AndroidNotification.channelId` (`FcmService`) e que o app React Native
/// cria: canal que o app não criou faz o Android cair num canal genérico, sem
/// som — e um SOS mudo às 3h da manhã é o mesmo que nenhum SOS.
class PushChannels {
  const PushChannels._();

  static const sosId = 'aura_sos';
  static const sosName = 'Pedidos de ajuda';
  static const sosDescription =
      'Avisos de socorro da casa: tocam e vibram mesmo no silencioso.';

  static const geralId = 'aura_geral';
  static const geralName = 'Pedidos e recomendações';
  static const geralDescription = 'Andamento de pedidos e novas recomendações.';

  /// O canal certo para o `data.kind` do aviso.
  static String forKind(String? kind) => isSos(kind) ? sosId : geralId;
}

/// Categoria que o backend põe no SOS ainda em aberto: é a que leva o botão
/// "Estou indo" (`FcmService.CATEGORY_SOS_ACK`).
const sosAckCategory = 'aura_sos_ack';

/// O SOS em aberto oferece "Estou indo" no próprio aviso.
bool offersAck(Map<String, dynamic> data) =>
    data['categoryId'] == sosAckCategory ||
    (isSos(data['kind'] as String?) && data['action'] == 'ack');

/// Um id por pedido de ajuda: o escalonamento, a retração e o resultado do
/// "Estou indo" substituem o aviso do mesmo SOS em vez de empilhar outro.
///
/// Hash próprio (FNV-1a de 31 bits) e não `String.hashCode`: o aviso é
/// desenhado num isolate e trocado em outro, e o id tem de bater nos dois.
int pushNotificationId(Map<String, dynamic> data) {
  final key = data['emergencyId'] ?? data['orderId'] ?? data['recommendationId'];
  if (key is! String || key.isEmpty) {
    return DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  }
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// `sos`, `sos_escalated` e `sos_cancelled` são avisos de crise.
bool isSos(String? kind) => kind != null && kind.startsWith('sos');

/// Para onde o toque no aviso leva, a partir do `data` do FCM. `null` quando
/// o aviso não tem destino (o app abre na tela inicial).
///
/// O SOS cancelado não abre a tela de socorro: ela ofereceria "Estou indo"
/// para um pedido que já não existe. Leva ao painel, onde o desfecho aparece.
String? deepLinkFor(Map<String, dynamic> data) {
  String? text(String key) {
    final value = data[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  final kind = text('kind');
  final emergencyId = text('emergencyId');
  if (emergencyId != null) {
    if (kind == 'sos_cancelled') return AppRoutes.dashboard;
    return AppRoutes.emergencyAlert(
      emergencyId,
      homeId: text('homeId'),
      address: text('address'),
      lat: text('lat'),
      lng: text('lng'),
    );
  }

  final orderId = text('orderId');
  if (orderId != null) return AppRoutes.orderDetail(orderId);

  if (text('recommendationId') != null || kind == 'recommendation') {
    return AppRoutes.careChain;
  }
  return null;
}
