import 'package:aura/core/errors/result.dart';
import 'package:aura/core/network/error_mapper.dart';
import '../../domain/entities/score.dart';
import '../../domain/repositories/scores_repository.dart';
import '../datasources/scores_remote_datasource.dart';
import '../models/score_mapper.dart';

class ScoresRepositoryImpl implements ScoresRepository {
  ScoresRepositoryImpl(this._remoteDataSource);

  final ScoresRemoteDataSource _remoteDataSource;

  @override
  Future<Result<List<Score>>> getScores(String homeId) async {
    try {
      final data = await _remoteDataSource.getScores(homeId);
      final scores = data
          .map((e) => scoreFromJson(e as Map<String, dynamic>))
          .toList();
      // Keep the latest score per dimension (backend returns newest first).
      final byDimension = <WellbeingDimensionType, Score>{};
      for (final s in scores) {
        byDimension.putIfAbsent(s.dimension, () => s);
      }
      return Success(byDimension.values.toList());
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<Score>> recompute(String homeId, {String? dimension}) async {
    try {
      final data =
          await _remoteDataSource.recompute(homeId, dimension: dimension);
      return Success(scoreFromJson(data));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }
}
