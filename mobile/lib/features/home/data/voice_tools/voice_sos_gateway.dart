import 'dart:async';

import 'package:aura/core/errors/result.dart';
import 'package:aura/features/sos/domain/entities/emergency.dart';

/// Ponte entre a tool `trigger_sos` e a tela.
///
/// A tool pede ao servidor, mas quem mostra a janela de cancelamento é a
/// folha de SOS. Sem ela na tela, "você tem alguns segundos para cancelar" seria
/// promessa sem botão — então a tool entrega à tela, por aqui, o que o servidor
/// respondeu. A tela só acompanha: **um pedido, um disparo** (quem registrou foi a tool).
class VoiceSosGateway {
  final StreamController<Result<EmergencyTicket>> _controller =
      StreamController<Result<EmergencyTicket>>.broadcast();

  Result<EmergencyTicket>? _pending;

  Stream<Result<EmergencyTicket>> get requests => _controller.stream;

  /// Entrega o desfecho. Sem ninguém ouvindo (a tela de voz fora da árvore, por
  /// exemplo), ele fica guardado: o servidor já abriu a janela de cancelamento,
  /// e a Maria precisa do botão quando a tela voltar — não de um desfecho perdido.
  void show(Result<EmergencyTicket> outcome) {
    if (_controller.isClosed) return;
    if (_controller.hasListener) {
      _controller.add(outcome);
    } else {
      _pending = outcome;
    }
  }

  /// O desfecho que ninguém viu, se houver (uma vez só).
  Result<EmergencyTicket>? takePending() {
    final pending = _pending;
    _pending = null;
    return pending;
  }

  void dispose() => _controller.close();
}
