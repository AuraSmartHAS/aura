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

  /// Só a Operação move a cadeia logística (`POST /orders/{id}/advance`): o backend
  /// responde 403 aos demais papéis, então a tela não oferece a ação a eles.
  bool get canAdvanceOrders => this == UserRole.admin;
}
