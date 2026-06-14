import 'package:aura/core/errors/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  Future<Result<UserEntity>> call(String email, String password) =>
      _repository.login(email, password);
}
