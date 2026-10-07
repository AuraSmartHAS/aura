import 'dart:async';

/// Ponte entre a tool `trigger_sos` e a tela.
///
/// A tool pede ao servidor, mas quem mostra a janela de cancelamento é a
/// folha de SOS. Sem ela na tela, "você tem alguns segundos para cancelar" seria
/// promessa sem botão — então a tool avisa a tela por aqui.
class VoiceSosGateway {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get requests => _controller.stream;

  void show() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() => _controller.close();
}
