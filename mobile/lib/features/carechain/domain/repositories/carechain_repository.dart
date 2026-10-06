import 'package:aura/core/errors/result.dart';
import 'package:aura/shared/models/severity_level.dart';
import '../entities/recommendation.dart';

abstract class CareChainRepository {
  /// Creates an explainable recommendation for the home (from a score). Price,
  /// installation and norm come in the same payload (correção C1).
  ///
  /// É idempotente no servidor: devolve a pendente do mesmo item, ou a já
  /// aprovada com o pedido em andamento, em vez de criar outra. A tela não decide
  /// nada disso.
  Future<Result<Recommendation>> createRecommendation({
    required String homeId,
    String? scoreId,
    required SeverityLevel level,
  });

  /// Approves the recommendation (RN-022) → returns the created order id.
  Future<Result<String>> approve(String recommendationId);
}
