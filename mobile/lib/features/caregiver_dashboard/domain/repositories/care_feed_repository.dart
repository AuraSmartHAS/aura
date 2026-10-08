import 'package:aura/core/errors/result.dart';

import '../entities/care_signal.dart';

/// O que a família vê da casa: sinais recentes e o SOS em aberto.
abstract class CareFeedRepository {
  /// Sinais desde [since] (hora local; o servidor recebe em UTC). Sem recorte de
  /// data, "os N últimos" misturam leituras do relógio que empurram a dose do
  /// dia para fora da página — e o painel passaria a afirmar "atrasada".
  Future<Result<List<CareSignal>>> getSignals(String homeId,
      {int limit = 200, DateTime? since, String? type});

  /// `null` quando não há SOS em aberto (204).
  Future<Result<ActiveEmergency?>> getActiveEmergency(String homeId);

  /// Como terminou um SOS que deixou de estar em aberto (alguém confirmou, ou a
  /// Maria cancelou). Sem isto, a faixa de quem não confirmou sumiria sem explicação.
  Future<Result<ActiveEmergency>> getEmergencyOutcome(String emergencyId);

  /// "Estou indo": fecha o loop e para o escalonamento.
  Future<Result<ActiveEmergency>> acknowledge(String emergencyId);
}
