import 'package:aura/core/errors/result.dart';
import '../entities/score.dart';
import '../repositories/scores_repository.dart';

class RecomputeScoreUseCase {
  RecomputeScoreUseCase(this._repository);

  final ScoresRepository _repository;

  Future<Result<Score>> call(String homeId, {String? dimension}) =>
      _repository.recompute(homeId, dimension: dimension);
}
