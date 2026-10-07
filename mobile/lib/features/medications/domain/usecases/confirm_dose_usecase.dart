import 'package:aura/core/errors/result.dart';
import '../entities/medication.dart';
import '../repositories/medication_repository.dart';

/// Registers that a dose was (or was not) taken. Adherence signal only —
/// nothing is prescribed.
class ConfirmDoseUseCase {
  ConfirmDoseUseCase(this._repository);

  final MedicationRepository _repository;

  /// [source] diz quem confirmou: `voice` (agente) ou `self_report` (toque,
  /// o padrão do servidor).
  Future<Result<DoseConfirmation>> call(String id,
          {required bool taken, String? source}) =>
      _repository.confirmDose(id, taken: taken, source: source);
}
