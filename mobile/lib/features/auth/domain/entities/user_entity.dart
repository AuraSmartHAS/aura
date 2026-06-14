import '../../../../core/session/user_role.dart';

/// Authenticated user as exposed to the presentation layer. The aura-server
/// `/auth/login` returns the role; the access/refresh tokens are persisted by
/// the data layer (not surfaced here).
class UserEntity {
  const UserEntity({required this.role, this.email});

  final UserRole role;
  final String? email;
}
