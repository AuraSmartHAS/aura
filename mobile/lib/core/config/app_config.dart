import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized, typed access to environment configuration loaded from `.env`.
///
/// Call [load] once during app bootstrap (before `setupServiceLocator`).
class AppConfig {
  const AppConfig._();

  /// Loads the `.env` file bundled as an asset. Safe to call once at startup.
  static Future<void> load() => dotenv.load(fileName: '.env');

  static String _get(String key, {String fallback = ''}) =>
      dotenv.maybeGet(key)?.trim().isNotEmpty == true
          ? dotenv.get(key).trim()
          : fallback;

  /// Root of the aura-server backend (e.g. `http://localhost:8000`).
  static String get backendBaseUrl =>
      _get('BACKEND_BASE_URL', fallback: 'http://localhost:8000');

  /// Full REST prefix consumed by the dio client.
  static String get apiBaseUrl => '$backendBaseUrl/api/v1';

  static String get googleMapsApiKey => _get('GOOGLE_MAPS_API_KEY');

  static String get supabaseUrl =>
      _get('SUPABASE_URL', fallback: 'https://pcdezajyayljowwgrksr.supabase.co');

  static String get supabaseKey => _get('SUPABASE_KEY');

  static String get fcmVapidKey => _get('FCM_VAPID_KEY');
}
