import 'package:aura/core/errors/result.dart';
import '../repositories/carechain_repository.dart';

class ApproveRecommendationUseCase {
  ApproveRecommendationUseCase(this._repository);

  final CareChainRepository _repository;

  /// Returns the created order id (RN-022).
  Future<Result<String>> call(String recommendationId) =>
      _repository.approve(recommendationId);
}
