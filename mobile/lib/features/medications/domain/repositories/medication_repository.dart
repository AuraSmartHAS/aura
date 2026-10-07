import 'package:aura/core/errors/result.dart';
import '../entities/medication.dart';

abstract class MedicationRepository {
  Future<Result<List<Medication>>> getMedications(String homeId);
  Future<Result<Medication>> create(String homeId, MedicationInput input);
  Future<Result<Medication>> update(String id, MedicationInput input);
  Future<Result<void>> delete(String id);
  Future<Result<DoseConfirmation>> confirmDose(String id,
      {required bool taken});
}
