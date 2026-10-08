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
  bool _sessionExpiredNotice = false;
  bool _patientGreetingDismissed = false;

  /// A Maria já interagiu na tela de voz nesta sessão do app. Só em memória:
  /// volta a falso quando o app fecha ou alguém sai da conta.
  bool get patientGreetingDismissed => _patientGreetingDismissed;
  void dismissPatientGreeting() => _patientGreetingDismissed = true;

  bool get isAuthenticated => _isAuthenticated;
  UserRole? get role => _role;
  bool get consentAccepted => _consentAccepted;
  String? get homeId => _homeId;

  /// Primeiro nome para a saudação, ou `null` quando o servidor não deu um
  /// nome de pessoa (a tela cumprimenta sem nome).
  String? get userFirstName => greetingFirstName(_userName);

  /// Há um aviso pendente de "sessão expirou" para a tela de login? Só um
  /// logout forçado (servidor deixou de reconhecer a sessão) o liga.
  bool get hasSessionExpiredNotice => _sessionExpiredNotice;

  /// Lê e apaga o aviso de sessão expirada — marcador de uma vez só: quem o
  /// consome (a tela de login) mostra a mensagem, e ninguém mais a vê.
  bool consumeSessionExpiredNotice() {
    final pending = _sessionExpiredNotice;
    _sessionExpiredNotice = false;
    return pending;
  }

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
    _sessionExpiredNotice = false;
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

  /// Encerra a sessão. [forced] indica que não foi o usuário quem saiu — o
  /// servidor recusou a sessão (token revogado, refresh falho, usuário
  /// inexistente) — e então a tela de login avisa por que voltou para ela.
  /// Só vale se havia sessão: um segundo logout forçado em sequência (várias
  /// requisições falhando juntas) não reacende um aviso já mostrado.
  Future<void> onLoggedOut({bool forced = false}) async {
    _sessionExpiredNotice = forced && _isAuthenticated;
    await _store.clear();
    _isAuthenticated = false;
    _role = null;
    _consentAccepted = false;
    _homeId = null;
    _userName = null;
    _patientGreetingDismissed = false;
    notifyListeners();
  }
}
