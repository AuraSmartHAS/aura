import 'package:aura/core/errors/result.dart';
import 'package:aura/core/network/error_mapper.dart';
import '../../domain/entities/medication.dart';
import '../../domain/repositories/medication_repository.dart';
import '../datasources/medication_remote_datasource.dart';
import '../models/medication_mapper.dart';

class MedicationRepositoryImpl implements MedicationRepository {
  MedicationRepositoryImpl(this._remoteDataSource);

  final MedicationRemoteDataSource _remoteDataSource;

  @override
  Future<Result<List<Medication>>> getMedications(String homeId) async {
    try {
      final data = await _remoteDataSource.getMedications(homeId);
      final meds = data
          .map((e) => medicationFromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return Success(meds);
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<Medication>> create(
    String homeId,
    MedicationInput input,
  ) async {
    try {
      final data =
          await _remoteDataSource.create(homeId, medicationCreateJson(input));
      return Success(medicationFromJson(data));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<Medication>> update(String id, MedicationInput input) async {
    try {
      final data =
          await _remoteDataSource.update(id, medicationUpdateJson(input));
      return Success(medicationFromJson(data));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _remoteDataSource.delete(id);
      return const Success(null);
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<DoseConfirmation>> confirmDose(
    String id, {
    required bool taken,
  }) async {
    try {
      final data = await _remoteDataSource.confirm(id, taken: taken);
      return Success(doseConfirmationFromJson(data));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }
}
