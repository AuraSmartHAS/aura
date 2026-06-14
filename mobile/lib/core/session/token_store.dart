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
  Future<void> saveHomeId(String homeId) =>
      _storage.write(key: _kHomeId, value: homeId);

  Future<bool> get consentAccepted async =>
      (await _storage.read(key: _kConsentAccepted)) == 'true';
  Future<void> setConsentAccepted() =>
      _storage.write(key: _kConsentAccepted, value: 'true');

  Future<void> clear() => _storage.deleteAll();
}
