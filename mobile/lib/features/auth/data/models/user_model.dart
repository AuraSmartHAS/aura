/// Parsed `/auth/login` (and `/auth/refresh`) response.
class AuthCredentialsModel {
  const AuthCredentialsModel({
    required this.token,
    required this.refreshToken,
    required this.role,
  });

  final String token;
  final String refreshToken;
  final String role;

  factory AuthCredentialsModel.fromJson(Map<String, dynamic> json) {
    return AuthCredentialsModel(
      token: json['token'] as String,
      refreshToken: (json['refreshToken'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'cuidadora',
    );
  }
}
