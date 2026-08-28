import 'package:aura/core/errors/result.dart';

import '../entities/emergency.dart';
import '../repositories/emergency_repository.dart';

/// Lê o estado do aviso. Chamado em laço pela tela, porque não existe push para
/// a Maria — é o polling que alimenta os quatro estados falados.
class GetEmergencyStatusUseCase {
  const GetEmergencyStatusUseCase(this._repository);

  final EmergencyRepository _repository;

  Future<Result<EmergencyStatus>> call(String emergencyId) =>
      _repository.status(emergencyId);
}
