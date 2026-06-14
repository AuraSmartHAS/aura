import 'package:aura/core/errors/result.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Result<UserEntity>> login(String email, String password);
  Future<Result<UserEntity>> signup(String email, String password);
  Future<Result<void>> logout();
  Future<Result<UserEntity?>> getCurrentUser();
}
