import 'package:aura/core/errors/result.dart';
import 'package:aura/shared/models/severity_level.dart';
import '../entities/recommendation.dart';
import '../repositories/carechain_repository.dart';

class CreateRecommendationUseCase {
  CreateRecommendationUseCase(this._repository);

  final CareChainRepository _repository;

  Future<Result<Recommendation>> call({
    required String homeId,
    String? scoreId,
    required SeverityLevel level,
  }) =>
      _repository.createRecommendation(
        homeId: homeId,
        scoreId: scoreId,
        level: level,
      );
}
