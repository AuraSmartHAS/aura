import 'package:aura/core/errors/result.dart';
import '../entities/medication.dart';
import '../repositories/medication_repository.dart';

class SaveMedicationUseCase {
  SaveMedicationUseCase(this._repository);

  final MedicationRepository _repository;

  Future<Result<void>> call(Medication medication) =>
      _repository.save(medication);
}
