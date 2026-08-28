import 'package:aura/core/errors/result.dart';

import '../entities/emergency.dart';
import '../repositories/emergency_repository.dart';

/// Registra o pedido de socorro no servidor.
class TriggerEmergencyUseCase {
  const TriggerEmergencyUseCase(this._repository);

  final EmergencyRepository _repository;

  Future<Result<EmergencyTicket>> call({
    EmergencyChannel channel = EmergencyChannel.touch,
  }) =>
      _repository.trigger(channel: channel);
}
