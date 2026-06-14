import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import '../../domain/entities/medication.dart';
import '../../domain/repositories/medication_repository.dart';
import '../datasources/medication_local_datasource.dart';

class MedicationRepositoryImpl implements MedicationRepository {
  MedicationRepositoryImpl(this._localDataSource);

  final MedicationLocalDataSource _localDataSource;

  @override
  Future<Result<List<Medication>>> getMedications(String homeId) async {
    try {
      return Success(await _localDataSource.getMedications(homeId));
    } catch (e) {
      return Failure(AppFailure.unexpected(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> save(Medication medication) async {
    try {
      await _localDataSource.upsert(medication);
      return const Success(null);
    } catch (e) {
      return Failure(AppFailure.unexpected(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _localDataSource.delete(id);
      return const Success(null);
    } catch (e) {
      return Failure(AppFailure.unexpected(message: e.toString()));
    }
  }
}
