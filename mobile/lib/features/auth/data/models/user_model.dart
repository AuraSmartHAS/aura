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

/// Parsed `GET /auth/me` response: só o que o app usa no login.
class MeModel {
  const MeModel({required this.consentAccepted, this.name});

  final bool consentAccepted;

  /// Nome cadastrado no servidor; pode faltar ou vir vazio.
  final String? name;

  factory MeModel.fromJson(Map<String, dynamic> json) {
    return MeModel(
      consentAccepted: json['consentAccepted'] == true,
      name: json['name'] as String?,
    );
  }
}
