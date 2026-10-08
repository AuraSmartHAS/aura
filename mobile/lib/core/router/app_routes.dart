class AppRoutes {
  // Auth
  static const String login = '/login';
  static const String signup = '/signup';
  static const String consent = '/consent';
  static const String selectProfile = '/select-profile';

  // Patient (voice-first)
  static const String voice = '/voice';

  // Caregiver (dashboard)
  static const String onboarding = '/onboarding';
  static const String dashboard = '/dashboard';
  static const String wellbeing = '/wellbeing';
  static const String careChain = '/carechain';
  static const String medications = '/medications';
  static const String wearable = '/wearable';

  // Orders & map (params via pathParameters)
  static const String orders = '/orders';
  static String orderDetail(String id) => '/orders/$id';
  static String map(String orderId) => '/map/$orderId';

  // SOS do lado de quem cuida: aberta pelo toque no aviso. O endereço e as
  // coordenadas vêm do `data` do push e viajam na query para a tela abrir já
  // com eles, sem esperar a rede.
  static const String emergencies = '/emergencies';
  static String emergencyAlert(
    String id, {
    String? homeId,
    String? address,
    String? lat,
    String? lng,
  }) {
    final query = {
      if (homeId != null) 'homeId': homeId,
      if (address != null) 'address': address,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
    return Uri(
      path: '$emergencies/$id',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  static const String credits = '/credits';
}
