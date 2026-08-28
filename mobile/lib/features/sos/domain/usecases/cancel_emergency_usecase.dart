import 'package:aura/core/errors/result.dart';

import '../entities/emergency.dart';
import '../repositories/emergency_repository.dart';

/// "Foi engano" — cancela dentro da janela do servidor.
class CancelEmergencyUseCase {
  const CancelEmergencyUseCase(this._repository);

  final EmergencyRepository _repository;

  Future<Result<EmergencyCancellation>> call(String emergencyId) =>
      _repository.cancel(emergencyId);
}
