import 'package:equatable/equatable.dart';

/// Um sinal da casa como o servidor guarda (`GET /homes/{id}/signals`). É a
/// matéria-prima da linha do tempo: a família lê o que a Maria disse e fez.
class CareSignal extends Equatable {
  const CareSignal({
    required this.id,
    required this.type,
    required this.source,
    required this.value,
    required this.capturedAt,
  });

  final String id;

  /// `adherence`, `mobility`, `sleep`, `vitals`...
  final String type;

  /// `voice`, `self_report`, `usage` ou `wearable`.
  final String source;
  final Map<String, dynamic> value;
  final DateTime capturedAt;

  @override
  List<Object?> get props => [id, type, source, value, capturedAt];
}

/// SOS em aberto da casa (`GET /homes/{id}/emergencies/active`).
class ActiveEmergency extends Equatable {
  const ActiveEmergency({
    required this.id,
    required this.state,
    required this.createdAt,
    this.acknowledgedByName,
    this.spokenMessage,
  });

  final String id;

  /// `waiting_cancel`, `dispatched` ou `escalated` enquanto aberta.
  final String state;
  final DateTime createdAt;
  final String? acknowledgedByName;
  final String? spokenMessage;

  /// Dentro da janela de cancelamento: a Maria ainda pode dizer "foi engano".
  bool get waitingCancel => state == 'waiting_cancel';

  /// Ainda pede resposta da família (waiting_cancel, dispatched ou escalated).
  bool get isOpen =>
      state == 'waiting_cancel' || state == 'dispatched' || state == 'escalated';

  /// Cópia que preserva o que o servidor não repete (o `AckResponse` não traz o
  /// `createdAt`: sem isto, "Pedido há 12 min" virava "Pedido agora").
  ActiveEmergency withCreatedAtFrom(ActiveEmergency? previous) {
    if (previous == null || previous.id != id) return this;
    return ActiveEmergency(
      id: id,
      state: state,
      createdAt: previous.createdAt,
      acknowledgedByName: acknowledgedByName,
      spokenMessage: spokenMessage,
    );
  }

  @override
  List<Object?> get props =>
      [id, state, createdAt, acknowledgedByName, spokenMessage];
}
