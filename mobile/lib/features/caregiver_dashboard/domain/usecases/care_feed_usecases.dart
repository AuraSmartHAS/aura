import 'package:aura/core/errors/result.dart';

import '../entities/care_signal.dart';
import '../repositories/care_feed_repository.dart';

class GetCareSignalsUseCase {
  const GetCareSignalsUseCase(this._repository);
  final CareFeedRepository _repository;

  Future<Result<List<CareSignal>>> call(String homeId,
          {int limit = 200, DateTime? since, String? type}) =>
      _repository.getSignals(homeId, limit: limit, since: since, type: type);
}

class GetActiveEmergencyUseCase {
  const GetActiveEmergencyUseCase(this._repository);
  final CareFeedRepository _repository;

  Future<Result<ActiveEmergency?>> call(String homeId) =>
      _repository.getActiveEmergency(homeId);
}

class AcknowledgeEmergencyUseCase {
  const AcknowledgeEmergencyUseCase(this._repository);
  final CareFeedRepository _repository;

  Future<Result<ActiveEmergency>> call(String emergencyId) =>
      _repository.acknowledge(emergencyId);
}

class GetEmergencyOutcomeUseCase {
  const GetEmergencyOutcomeUseCase(this._repository);
  final CareFeedRepository _repository;

  Future<Result<ActiveEmergency>> call(String emergencyId) =>
      _repository.getEmergencyOutcome(emergencyId);
}
