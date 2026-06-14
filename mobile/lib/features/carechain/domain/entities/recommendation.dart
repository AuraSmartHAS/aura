import 'package:aura/shared/models/severity_level.dart';

/// Explainable recommendation (POST /recommendations) enriched with catalog
/// details, ready to render in the ExplainableRecommendationCard.
class Recommendation {
  const Recommendation({
    required this.recommendationId,
    required this.sku,
    required this.productName,
    required this.price,
    required this.reason,
    required this.normRef,
    required this.factors,
    required this.weights,
    required this.level,
  });

  final String recommendationId;
  final String sku;
  final String productName;
  final double? price;
  final String reason;
  final String normRef;
  final List<String> factors;
  final List<double> weights;
  final SeverityLevel level;
}
