import 'package:aura/core/errors/result.dart';
import '../entities/score.dart';

abstract class ScoresRepository {
  /// Latest score per dimension for the home.
  Future<Result<List<Score>>> getScores(String homeId);

  /// Recomputes a dimension (or all, returning the highest risk) and returns it.
  Future<Result<Score>> recompute(String homeId, {String? dimension});
}
