import 'package:aura/core/errors/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignupUseCase {
  SignupUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<UserEntity>> call(String email, String password, String role) =>
      _repository.signup(email, password, role);
}
