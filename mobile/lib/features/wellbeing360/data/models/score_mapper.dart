import 'package:aura/shared/models/severity_level.dart';
import '../../domain/entities/score.dart';

/// Parses an aura-server score object (from `/scores/recompute` or
/// `/homes/{id}/scores`) into a [Score] entity.
Score scoreFromJson(Map<String, dynamic> json) {
  return Score(
    scoreId: (json['scoreId'] as String?) ?? '',
    dimension:
        WellbeingDimensionType.fromApi((json['dimension'] as String?) ?? 'mobility'),
    level: SeverityLevel.fromScoreLevel(json['level'] as String?),
    score: (json['score'] as num?)?.toDouble() ?? 0,
    factors: ((json['factors'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    weights: ((json['weights'] as List?) ?? const [])
        .map((e) => (e as num).toDouble())
        .toList(),
    explanation: (json['explanation'] as String?) ?? '',
    configVersion: json['configVersion'] as String?,
  );
}
