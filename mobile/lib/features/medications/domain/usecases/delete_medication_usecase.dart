import 'package:aura/core/errors/result.dart';
import '../repositories/medication_repository.dart';

class DeleteMedicationUseCase {
  DeleteMedicationUseCase(this._repository);

  final MedicationRepository _repository;

  Future<Result<void>> call(String id) => _repository.delete(id);
}
