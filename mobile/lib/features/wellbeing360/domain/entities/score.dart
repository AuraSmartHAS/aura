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
    this.factorLabels = const [],
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

  /// Rótulos em português dos fatores, na mesma ordem de [factors]. Vêm da API
  /// (a política de risco vive em YAML versionado).
  final List<String> factorLabels;

  /// Fator pronto para a tela: o rótulo do servidor e, só na falta dele, o
  /// código com espaços — nunca `near_fall_reported` cru.
  String factorLabel(int index) =>
      index < factorLabels.length && factorLabels[index].trim().isNotEmpty
          ? factorLabels[index]
          : factors[index].replaceAll('_', ' ');
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
