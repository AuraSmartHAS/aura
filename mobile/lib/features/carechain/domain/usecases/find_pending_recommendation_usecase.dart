import 'package:aura/core/errors/result.dart';
import 'package:aura/shared/models/severity_level.dart';
import '../entities/recommendation.dart';
import '../repositories/carechain_repository.dart';

/// Reaproveita a recomendação que ainda espera decisão em vez de criar outra —
/// sem isto, abrir a tela cinco vezes enche o painel com cinco recomendações
/// iguais.
class FindPendingRecommendationUseCase {
  FindPendingRecommendationUseCase(this._repository);

  final CareChainRepository _repository;

  Future<Result<Recommendation?>> call({
    required String homeId,
    required SeverityLevel level,
  }) =>
      _repository.findPendingRecommendation(homeId: homeId, level: level);
}
