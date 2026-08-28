/// Entidades do fluxo de socorro (correção C3).
///
/// O contrato (`docs/api/openapi.json`, tag "8. SOS e crise") foi desenhado para
/// impedir a tela de mentir: além do estado, ele devolve **se o aviso pode ser
/// prometido** e **a frase segura para dizer neste estado**. Estas classes
/// existem para carregar as duas coisas até a apresentação sem perdê-las pelo
/// caminho.
library;

/// Como o socorro foi pedido.
enum EmergencyChannel {
  touch,
  voice;

  String get wireValue => name;
}

/// Estado da emergência no **servidor** — a única fonte da verdade.
///
/// A contagem que a Maria vê é feedback visual; o disparo mora no servidor
/// (regra 2), então é daqui que sai tudo o que a tela afirma.
enum EmergencyState {
  /// Registrada, dentro da janela de cancelamento. Nada saiu ainda.
  waitingCancel,

  /// O servidor disparou o aviso.
  dispatched,

  /// Sem confirmação na janela: o aviso foi aos demais membros da casa.
  escalated,

  /// A cuidadora confirmou ("estou indo").
  acknowledged,

  /// "Foi engano" — cancelada.
  cancelled,

  /// Disparo contido pela mitigação de abuso do acesso sem login.
  throttled,

  /// Valor que este app não conhece. Nunca vira promessa: cai no caminho de
  /// ligação, como qualquer outra coisa que não se pode afirmar.
  unknown;

  static EmergencyState fromWire(String? value) {
    switch (value) {
      case 'waiting_cancel':
        return EmergencyState.waitingCancel;
      case 'dispatched':
        return EmergencyState.dispatched;
      case 'escalated':
        return EmergencyState.escalated;
      case 'acknowledged':
        return EmergencyState.acknowledged;
      case 'cancelled':
        return EmergencyState.cancelled;
      case 'throttled':
        return EmergencyState.throttled;
      default:
        return EmergencyState.unknown;
    }
  }
}

/// Por que o servidor não pode prometer o aviso (`degradedReason`).
///
/// Os três motivos levam ao mesmo lugar — a ligação —, mas cada um explica algo
/// diferente para a Maria, e ela merece saber qual é.
enum DegradedReason {
  /// Não existe transporte real de push neste servidor (regra 1: um SOS
  /// simulado jamais aparece como se fosse real).
  simulatedTransport,

  /// A casa não tem aparelho registrado para receber o aviso.
  noRegisteredDevice,

  /// Disparo contido pela mitigação de abuso.
  throttled,

  /// Motivo novo, ainda desconhecido por este app.
  unknown;

  static DegradedReason? fromWire(String? value) {
    if (value == null || value.isEmpty) return null;
    switch (value) {
      case 'simulated_transport':
        return DegradedReason.simulatedTransport;
      case 'no_registered_device':
        return DegradedReason.noRegisteredDevice;
      case 'throttled':
        return DegradedReason.throttled;
      default:
        return DegradedReason.unknown;
    }
  }
}

/// Resposta do registro do pedido (`POST /emergencies`).
///
/// Chega **antes** de qualquer push: é o recibo de que o servidor assumiu o
/// disparo.
class EmergencyTicket {
  const EmergencyTicket({
    required this.id,
    required this.state,
    required this.cancelWindowSeconds,
    required this.canPromiseAlert,
    this.dispatchAt,
    this.escalateAfterSeconds,
    this.transportReal = false,
    this.simulated = true,
    this.recipientCount = 0,
    this.primaryContactName,
    this.throttled = false,
    this.deduplicated = false,
    this.degradedReason,
    this.spokenMessage,
  });

  final String id;
  final EmergencyState state;
  final DateTime? dispatchAt;

  /// Segundos de janela de cancelamento (5, por contrato). É o número que a
  /// contagem visual usa — o relógio que vale é o do servidor.
  final int cancelWindowSeconds;
  final int? escalateAfterSeconds;
  final bool transportReal;
  final bool simulated;
  final int recipientCount;

  /// Primeiro nome do contato principal, para a fala do assistente.
  final String? primaryContactName;
  final bool throttled;

  /// Toque repetido: devolveu a emergência que já estava aberta.
  final bool deduplicated;

  /// **A única pergunta que a tela faz antes de prometer "avisei a Ana".**
  final bool canPromiseAlert;
  final DegradedReason? degradedReason;

  /// Frase segura para dizer neste estado, escrita pelo servidor. A tela pode
  /// trocar a redação, nunca aumentar a promessa — então ela não troca.
  final String? spokenMessage;
}

/// Resposta do acompanhamento (`GET /emergencies/{id}`), lida por polling: não
/// há push para a Maria.
class EmergencyStatus {
  const EmergencyStatus({
    required this.id,
    required this.state,
    required this.canPromiseAlert,
    this.dispatchedAt,
    this.acknowledgedAt,
    this.acknowledgedByName,
    this.escalated = false,
    this.notifiedCount = 0,
    this.transportReal = false,
    this.simulated = true,
    this.degradedReason,
    this.spokenMessage,
  });

  final String id;
  final EmergencyState state;
  final DateTime? dispatchedAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByName;
  final bool escalated;
  final int notifiedCount;
  final bool transportReal;
  final bool simulated;
  final bool canPromiseAlert;
  final DegradedReason? degradedReason;
  final String? spokenMessage;
}

/// Resposta do cancelamento (`POST /emergencies/{id}/cancel`).
class EmergencyCancellation {
  const EmergencyCancellation({
    required this.id,
    required this.state,
    required this.withinWindow,
    required this.alertSent,
    required this.retractionSent,
    this.simulated = true,
    this.spokenMessage,
  });

  final String id;
  final EmergencyState state;

  /// `true` = chegou antes do disparador. `false` = o aviso já tinha saído, e
  /// **nada é desfeito** — a retração vai de todo modo.
  final bool withinWindow;
  final bool alertSent;
  final bool retractionSent;
  final bool simulated;
  final String? spokenMessage;
}

/// O aparelho não sabe a qual casa pertence, então não há a quem avisar.
///
/// Caso real na tela de abertura de uma instalação nova. Não é erro de rede e
/// não pode virar a frase de rede: o que resta é a ligação.
class DeviceNotPairedFailure implements Exception {
  const DeviceNotPairedFailure();

  @override
  String toString() => 'DeviceNotPairedFailure';
}
