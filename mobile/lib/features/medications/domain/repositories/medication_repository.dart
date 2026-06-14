import 'package:aura/core/errors/result.dart';
import '../entities/medication.dart';

abstract class MedicationRepository {
  Future<Result<List<Medication>>> getMedications(String homeId);
  Future<Result<void>> save(Medication medication);
  Future<Result<void>> delete(String id);
}
