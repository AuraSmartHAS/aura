import 'package:aura/core/errors/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignupUseCase {
  final AuthRepository _repository;

  SignupUseCase(this._repository);

  Future<Result<UserEntity>> call(String email, String password) =>
      _repository.signup(email, password);
}
