import 'package:aura/core/errors/result.dart';
import '../entities/medication.dart';
import '../repositories/medication_repository.dart';

/// Creates the medication when `id` is null, otherwise updates it.
class SaveMedicationUseCase {
  SaveMedicationUseCase(this._repository);

  final MedicationRepository _repository;

  Future<Result<Medication>> call(
    String homeId,
    MedicationInput input, {
    String? id,
  }) =>
      id == null
          ? _repository.create(homeId, input)
          : _repository.update(id, input);
}
