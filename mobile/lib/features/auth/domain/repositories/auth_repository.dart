import 'package:aura/core/errors/result.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Result<UserEntity>> login(String email, String password);

  /// Signs up then logs in to obtain a full session (token + refresh + role).
  Future<Result<UserEntity>> signup(String email, String password, String role);

  Future<Result<void>> logout();
}
