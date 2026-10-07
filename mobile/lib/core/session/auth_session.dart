import 'package:flutter/foundation.dart';

import 'greeting_name.dart';
import 'token_store.dart';
import 'user_role.dart';

/// In-memory snapshot of the authenticated session, kept in sync with
/// [TokenStore]. Exposed as a [ChangeNotifier] so `go_router` can refresh
/// guards when auth state changes (login/logout/consent).
class AuthSession extends ChangeNotifier {
  AuthSession(this._store);

  final TokenStore _store;

  bool _isAuthenticated = false;
  UserRole? _role;
  bool _consentAccepted = false;
  String? _homeId;
  String? _userName;

  bool get isAuthenticated => _isAuthenticated;
  UserRole? get role => _role;
  bool get consentAccepted => _consentAccepted;
  String? get homeId => _homeId;

  /// Primeiro nome para a saudação, ou `null` quando o servidor não deu um
  /// nome de pessoa (a tela cumprimenta sem nome).
  String? get userFirstName => greetingFirstName(_userName);

  /// Hydrates the session from secure storage at startup.
  Future<void> bootstrap() async {
    final token = await _store.accessToken;
    _isAuthenticated = token != null && token.isNotEmpty;
    _role = UserRole.fromString(await _store.role);
    _consentAccepted = await _store.consentAccepted;
    _homeId = await _store.homeId;
    _userName = await _store.userName;
    notifyListeners();
  }

  Future<void> onLoggedIn(UserRole role) async {
    _isAuthenticated = true;
    _role = role;
    _consentAccepted = await _store.consentAccepted;
    _homeId = await _store.homeId;
    _userName = await _store.userName;
    notifyListeners();
  }

  void onConsentAccepted() {
    _consentAccepted = true;
    notifyListeners();
  }

  void setHomeId(String homeId) {
    _homeId = homeId;
    notifyListeners();
  }

  Future<void> onLoggedOut() async {
    await _store.clear();
    _isAuthenticated = false;
    _role = null;
    _consentAccepted = false;
    _homeId = null;
    _userName = null;
    notifyListeners();
  }
}
