/// RBAC roles exposed by the aura-server (`/auth/login` → `role`).
enum UserRole {
  paciente,
  cuidadora,
  profissional,
  admin;

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.cuidadora,
    );
  }

  /// Patients use the voice-first surface; everyone else uses the dashboard.
  bool get isPatient => this == UserRole.paciente;
}
