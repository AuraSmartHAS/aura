import '../../domain/entities/medication.dart';

Medication medicationFromJson(Map<String, dynamic> json) {
  return Medication(
    id: json['id'] as String,
    homeId: json['homeId'] as String,
    name: json['name'] as String,
    dosage: json['dosage'] as String?,
    times: (json['schedule'] as List?)?.map((t) => t as String).toList() ??
        const [],
    notes: json['notes'] as String?,
    active: (json['active'] as bool?) ?? true,
    stockDoses: (json['stockDoses'] as num?)?.toInt(),
  );
}

/// Body for `POST /homes/{homeId}/medications`: absent fields are omitted.
Map<String, dynamic> medicationCreateJson(MedicationInput input) => {
      'name': input.name,
      if (input.dosage != null) 'dosage': input.dosage,
      'schedule': input.times,
      if (input.notes != null) 'notes': input.notes,
      if (input.stockDoses != null) 'stockDoses': input.stockDoses,
    };

/// Body for `PUT /medications/{id}`. The server applies a partial update (a
/// null field is left as is), so a field the caregiver cleared is sent as an
/// empty value to actually clear it. Stock cannot be cleared, only changed.
Map<String, dynamic> medicationUpdateJson(MedicationInput input) => {
      'name': input.name,
      'dosage': input.dosage ?? '',
      'schedule': input.times,
      'notes': input.notes ?? '',
      if (input.stockDoses != null) 'stockDoses': input.stockDoses,
    };

DoseConfirmation doseConfirmationFromJson(Map<String, dynamic> json) {
  return DoseConfirmation(
    signalId: json['signalId'] as String,
    taken: json['taken'] as bool,
    stockDoses: (json['stockDoses'] as num?)?.toInt(),
  );
}
