import 'package:aura/core/errors/result.dart';
import '../repositories/auth_repository.dart';

class LogoutUseCase {
  final AuthRepository _repository;

  LogoutUseCase(this._repository);

  Future<Result<void>> call() => _repository.logout();
}
