import 'package:aura/core/errors/result.dart';
import '../entities/medication.dart';
import '../repositories/medication_repository.dart';

/// Registers that a dose was (or was not) taken. Adherence signal only —
/// nothing is prescribed.
class ConfirmDoseUseCase {
  ConfirmDoseUseCase(this._repository);

  final MedicationRepository _repository;

  Future<Result<DoseConfirmation>> call(String id, {required bool taken}) =>
      _repository.confirmDose(id, taken: taken);
}
