import 'package:aura/core/errors/result.dart';
import 'package:aura/shared/models/severity_level.dart';
import '../entities/recommendation.dart';

abstract class CareChainRepository {
  /// Creates an explainable recommendation for the home (from a score). Price,
  /// installation and norm come in the same payload (correção C1).
  Future<Result<Recommendation>> createRecommendation({
    required String homeId,
    String? scoreId,
    required SeverityLevel level,
  });

  /// A recomendação mais recente que ainda espera decisão, ou `null` quando não
  /// há nenhuma. Abrir a tela reaproveita esta em vez de criar outra.
  Future<Result<Recommendation?>> findPendingRecommendation({
    required String homeId,
    required SeverityLevel level,
  });

  /// Approves the recommendation (RN-022) → returns the created order id.
  Future<Result<String>> approve(String recommendationId);
}
