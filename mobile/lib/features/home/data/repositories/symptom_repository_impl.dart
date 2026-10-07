import 'package:aura/core/errors/result.dart';
import 'package:aura/core/network/error_mapper.dart';
import '../../domain/repositories/symptom_repository.dart';
import '../datasources/symptom_remote_datasource.dart';

class SymptomRepositoryImpl implements SymptomRepository {
  SymptomRepositoryImpl(this._remote);

  final SymptomRemoteDataSource _remote;

  @override
  Future<Result<String>> register({
    required String homeId,
    required String type,
    required Map<String, dynamic> value,
  }) async {
    try {
      final id = await _remote.postVoiceSignal(
        homeId: homeId,
        type: type,
        value: value,
      );
      return Success(id);
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }
}
