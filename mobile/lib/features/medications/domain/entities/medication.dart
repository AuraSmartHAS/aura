/// A medication entry managed by the caregiver. Local-only for now; the field
/// set mirrors the proposed backend DTO (see docs/PROPOSTA-medications-api.md).
class Medication {
  const Medication({
    required this.id,
    required this.homeId,
    required this.name,
    this.dosage,
    this.schedule,
    this.notes,
  });

  final String id;
  final String homeId;
  final String name;
  final String? dosage;
  final String? schedule;
  final String? notes;

  Medication copyWith({
    String? name,
    String? dosage,
    String? schedule,
    String? notes,
  }) {
    return Medication(
      id: id,
      homeId: homeId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      schedule: schedule ?? this.schedule,
      notes: notes ?? this.notes,
    );
  }
}
