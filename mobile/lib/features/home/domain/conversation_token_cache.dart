import 'dart:async';

import 'package:aura/core/errors/result.dart';

/// Um token de conversa buscado na abertura da tela, para o primeiro toque no
/// microfone não esperar a ElevenLabs gerar um (medido: de 3 a 16 s).
///
/// **Um só, e sem renovação.** Cada token emitido parece reservar uma vaga de
/// conversa simultânea na ElevenLabs até vencer (15 min), mesmo sem ser usado
/// — com a conta cheia de tokens parados e nenhuma conversa ativa, o endpoint
/// passou a responder 429 `workspace_concurrency_limit_exceeded`. Renovar ou
/// já buscar o próximo ocuparia mais vagas de um plano que tem 4.
///
/// Por isso:
/// - o token é de uso único (C7a): [take] entrega o guardado uma vez só;
/// - guardado há mais de [maxAge] (folga sobre os 15 min) não é usado;
/// - sem token guardado, [take] busca na hora, como antes — inclusive nas
///   conversas seguintes à primeira;
/// - o toque que chega com a busca da abertura em andamento espera essa mesma
///   busca, em vez de começar outra;
/// - falha na busca da abertura é silenciosa: o erro aparece no toque.
class ConversationTokenCache {
  ConversationTokenCache(
    this._fetch, {
    this.maxAge = const Duration(minutes: 13),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Future<Result<String>> Function() _fetch;
  final Duration maxAge;
  final DateTime Function() _now;

  String? _token;
  DateTime? _fetchedAt;
  Future<void>? _inFlight;
  bool _disposed = false;

  bool get _fresh =>
      _token != null &&
      _fetchedAt != null &&
      _now().difference(_fetchedAt!) < maxAge;

  /// Busca o token da abertura da tela (uma vez; chamadas repetidas não
  /// buscam outro enquanto houver um guardado ou uma busca em curso).
  void warmUp() {
    if (_disposed || _fresh || _inFlight != null) return;
    final run = _fetch().then((result) {
      if (_disposed) return;
      if (result case Success(:final data)) {
        _token = data;
        _fetchedAt = _now();
      }
    }).catchError((Object _) {});
    _inFlight = run.whenComplete(() => _inFlight = null);
  }

  /// O token desta conversa: o guardado (consumido), o da busca em curso, ou
  /// um buscado na hora.
  Future<Result<String>> take() async {
    if (!_fresh && _inFlight != null) await _inFlight;
    if (_fresh) {
      final token = _token!;
      _token = null;
      _fetchedAt = null;
      return Success(token);
    }
    _token = null;
    _fetchedAt = null;
    return _fetch();
  }

  void dispose() {
    _disposed = true;
  }
}
