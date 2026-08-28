import 'package:aura/core/errors/result.dart';

import '../entities/emergency.dart';

/// Porta do fluxo de socorro (correção C3).
///
/// As três primeiras rotas são **abertas** no contrato: o SOS não fica atrás de
/// login (regra 3). Quem resolve o identificador da casa é a implementação, a
/// partir do que o aparelho guarda — não da sessão, que pode ter expirado.
abstract class EmergencyRepository {
  /// Registra o pedido de socorro. Devolve na hora, antes de qualquer push: o
  /// disparo é do servidor e não depende deste aparelho continuar vivo.
  Future<Result<EmergencyTicket>> trigger({required EmergencyChannel channel});

  /// "Foi engano." Dentro da janela o aviso original não sai; fora dela nada é
  /// desfeito, e a retração vai de todo modo.
  Future<Result<EmergencyCancellation>> cancel(String emergencyId);

  /// Estado do aviso. É por aqui que a tela acompanha — não há push para a
  /// Maria.
  Future<Result<EmergencyStatus>> status(String emergencyId);
}
