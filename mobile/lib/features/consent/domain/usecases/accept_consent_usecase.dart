import 'package:aura/core/errors/result.dart';
import '../repositories/consent_repository.dart';

class AcceptConsentUseCase {
  AcceptConsentUseCase(this._repository);

  final ConsentRepository _repository;

  Future<Result<void>> call() => _repository.accept();
}
