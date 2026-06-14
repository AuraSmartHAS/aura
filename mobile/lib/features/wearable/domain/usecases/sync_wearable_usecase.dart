import 'package:aura/core/errors/result.dart';
import '../entities/vitals.dart';
import '../repositories/wearable_repository.dart';

class SyncWearableUseCase {
  SyncWearableUseCase(this._repository);

  final WearableRepository _repository;

  Future<Result<Vitals>> call() => _repository.syncVitals();
}
