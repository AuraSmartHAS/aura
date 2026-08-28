import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists auth credentials and the active home id in the OS secure storage.
///
/// Replaces the previous reliance on `FirebaseAuth.currentUser`: the app now
/// authenticates against the aura-server JWT (`/auth/login`).
class TokenStore {
  TokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kRole = 'role';
  static const _kHomeId = 'home_id';
  static const _kPairedHomeId = 'paired_home_id';
  static const _kConsentAccepted = 'consent_accepted';

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String role,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
    await _storage.write(key: _kRole, value: role);
  }

  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  Future<String?> get accessToken => _storage.read(key: _kAccessToken);
  Future<String?> get refreshToken => _storage.read(key: _kRefreshToken);
  Future<String?> get role => _storage.read(key: _kRole);

  Future<String?> get homeId => _storage.read(key: _kHomeId);

  Future<void> saveHomeId(String homeId) async {
    await _storage.write(key: _kHomeId, value: homeId);
    await _storage.write(key: _kPairedHomeId, value: homeId);
  }

  /// Casa a que este aparelho pertence — **a única coisa que sobrevive ao fim
  /// da sessão** (correção C3, regra 3).
  ///
  /// O SOS não fica atrás de login: se a sessão expirar, o socorro não pode
  /// depender de uma senha que a Maria não vai digitar no chão do banheiro. Sem
  /// esta chave o botão de emergência ficaria sem saber a quem avisar
  /// exatamente no momento em que mais importa.
  ///
  /// Fica em chave separada de propósito: a sessão continua limpando `home_id`,
  /// então nada no resto do app passa a ver a casa de um usuário anterior.
  Future<String?> get pairedHomeId => _storage.read(key: _kPairedHomeId);

  Future<bool> get consentAccepted async =>
      (await _storage.read(key: _kConsentAccepted)) == 'true';
  Future<void> setConsentAccepted() =>
      _storage.write(key: _kConsentAccepted, value: 'true');

  Future<void> clear() async {
    final pairedHome = await pairedHomeId;
    await _storage.deleteAll();
    if (pairedHome != null) {
      await _storage.write(key: _kPairedHomeId, value: pairedHome);
    }
  }
}
