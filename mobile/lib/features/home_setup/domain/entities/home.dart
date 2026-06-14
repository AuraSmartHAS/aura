/// A patient's home (the unit everything keys off — scores, recommendations,
/// orders). Maps the aura-server `home` object.
class Home {
  const Home({
    required this.id,
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String label;
  final String address;
  final double? lat;
  final double? lng;
}

/// Full home detail (`GET /homes/{id}`): home + patient + safety checklist.
class HomeDetail {
  const HomeDetail({
    required this.home,
    required this.patientName,
    required this.checklist,
  });

  final Home home;
  final String? patientName;

  /// Safety checklist keyed by the aura-server keys (`grab_bar_bathroom`, ...).
  /// A missing/false item counts as risk and feeds the score.
  final Map<String, bool> checklist;
}

/// Canonical safety checklist keys used by the scoring engine.
class SafetyChecklistKeys {
  const SafetyChecklistKeys._();

  static const grabBarBathroom = 'grab_bar_bathroom';
  static const slipperyFloor = 'slippery_floor';
  static const nightLight = 'night_light';
  static const gasDetector = 'gas_detector';
  static const airPurifier = 'air_purifier';

  static const all = [
    grabBarBathroom,
    slipperyFloor,
    nightLight,
    gasDetector,
    airPurifier,
  ];

  static String label(String key) {
    switch (key) {
      case grabBarBathroom:
        return 'Barra de apoio no banheiro';
      case slipperyFloor:
        return 'Piso escorregadio';
      case nightLight:
        return 'Luz noturna com sensor';
      case gasDetector:
        return 'Detector de gás/fumaça';
      case airPurifier:
        return 'Purificador de ar';
      default:
        return key;
    }
  }

  /// Whether a `true` value represents a *safe* condition. `slippery_floor` is
  /// inverted: marking it true means a hazard is present.
  static bool trueIsSafe(String key) => key != slipperyFloor;
}
