import 'package:aura/core/errors/result.dart';
import 'package:aura/shared/models/severity_level.dart';
import '../entities/recommendation.dart';

abstract class CareChainRepository {
  /// Creates an explainable recommendation for the home (from a score), then
  /// enriches it with catalog details (name, price, norm).
  Future<Result<Recommendation>> createRecommendation({
    required String homeId,
    String? scoreId,
    required SeverityLevel level,
  });

  /// Approves the recommendation (RN-022) → returns the created order id.
  Future<Result<String>> approve(String recommendationId);
}
