import 'package:aura/core/errors/result.dart';
import '../entities/medication.dart';
import '../repositories/medication_repository.dart';

class GetMedicationsUseCase {
  GetMedicationsUseCase(this._repository);

  final MedicationRepository _repository;

  Future<Result<List<Medication>>> call(String homeId) =>
      _repository.getMedications(homeId);
}
