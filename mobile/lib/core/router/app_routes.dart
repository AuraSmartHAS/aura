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

  static const String credits = '/credits';
}
