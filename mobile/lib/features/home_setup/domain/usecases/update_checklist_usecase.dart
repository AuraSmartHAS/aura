import 'package:aura/core/errors/result.dart';
import '../repositories/home_repository.dart';

class UpdateChecklistUseCase {
  UpdateChecklistUseCase(this._repository);

  final HomeRepository _repository;

  Future<Result<Map<String, bool>>> call(
    String homeId,
    Map<String, bool> items,
  ) =>
      _repository.updateChecklist(homeId, items);
}
