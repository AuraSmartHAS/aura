import 'package:aura/core/errors/result.dart';
import '../entities/score.dart';
import '../repositories/scores_repository.dart';

class GetScoresUseCase {
  GetScoresUseCase(this._repository);

  final ScoresRepository _repository;

  Future<Result<List<Score>>> call(String homeId) =>
      _repository.getScores(homeId);
}
