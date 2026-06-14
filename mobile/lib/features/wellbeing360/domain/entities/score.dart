import 'package:aura/shared/models/severity_level.dart';

/// Explainable risk score for one wellbeing dimension (aura-server `score`).
class Score {
  const Score({
    required this.scoreId,
    required this.dimension,
    required this.level,
    required this.score,
    required this.factors,
    required this.weights,
    required this.explanation,
    this.configVersion,
  });

  final String scoreId;
  final WellbeingDimensionType dimension;
  final SeverityLevel level;
  final double score;

  /// Parallel lists: each factor with its weight.
  final List<String> factors;
  final List<double> weights;
  final String explanation;
  final String? configVersion;
}

/// Wellbeing dimensions tracked by the scoring engine (`score.dimension`).
enum WellbeingDimensionType {
  mobility,
  sleep,
  cognition,
  environment;

  static WellbeingDimensionType fromApi(String value) =>
      WellbeingDimensionType.values.firstWhere(
        (d) => d.name == value,
        orElse: () => WellbeingDimensionType.mobility,
      );

  String get label {
    switch (this) {
      case WellbeingDimensionType.mobility:
        return 'Mobilidade';
      case WellbeingDimensionType.sleep:
        return 'Sono';
      case WellbeingDimensionType.cognition:
        return 'Cognição';
      case WellbeingDimensionType.environment:
        return 'Ambiente';
    }
  }
}
