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

  /// Raiz da API do AURA. O padrão é a API Spring Boot desta fase, na porta 8080
  /// (`backend-spring`). O fallback antigo apontava para `:8000`, do serviço
  /// Python da Fase 4, que está parado desde 14/06 — quem clonava o repositório
  /// sem `.env` subia o app contra um backend inexistente.
  static String get backendBaseUrl =>
      _get('BACKEND_BASE_URL', fallback: 'http://localhost:8080');

  /// Full REST prefix consumed by the dio client.
  static String get apiBaseUrl => '$backendBaseUrl/api/v1';

  static String get googleMapsApiKey => _get('GOOGLE_MAPS_API_KEY');

  static String get supabaseUrl =>
      _get('SUPABASE_URL', fallback: 'https://pcdezajyayljowwgrksr.supabase.co');

  static String get supabaseKey => _get('SUPABASE_KEY');

  static String get fcmVapidKey => _get('FCM_VAPID_KEY');

  /// Telefone do contato principal da casa, para o caminho de ligação do SOS
  /// (correção C3, regra 1). A API de emergência devolve o **nome** do contato,
  /// nunca o telefone — o corpo é magro de propósito porque a rota é aberta.
  /// Vazio aqui significa que a tela do SOS só oferece o 192.
  static String get sosContactPhone => _get('SOS_CONTACT_PHONE');

  /// Emergência pública. Botão que **a pessoa** toca, nunca discagem
  /// automática (decisão D19).
  static String get sosEmergencyPhone =>
      _get('SOS_EMERGENCY_PHONE', fallback: '192');
}
