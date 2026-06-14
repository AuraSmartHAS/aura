/// Lightweight wellbeing readings from the user's own device (Health Connect /
/// HealthKit). Guardrail: wellbeing signal, NOT a diagnosis.
class Vitals {
  const Vitals({this.steps, this.restingHeartRate, this.sleepHours});

  final int? steps;
  final double? restingHeartRate;
  final double? sleepHours;

  Map<String, dynamic> toSignalValue() => {
        if (steps != null) 'steps': steps,
        if (restingHeartRate != null) 'restingHeartRate': restingHeartRate,
        if (sleepHours != null) 'sleepHours': sleepHours,
      };
}

/// Thrown when the user declines Health Connect / HealthKit access.
class WearablePermissionException implements Exception {
  const WearablePermissionException();
}

/// Thrown when Health Connect is not available on the device (e.g. not yet
/// installed on Android < 14). The data layer triggers the install flow before
/// surfacing this so the user can complete setup and retry.
class WearableUnavailableException implements Exception {
  const WearableUnavailableException();
}
