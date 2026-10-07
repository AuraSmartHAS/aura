import 'package:aura/core/errors/result.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart' as sdk;

import '../../presentation/home_error_copy.dart';

/// Falha de tool → frase curta para o agente repetir à Maria.
///
/// O agente nunca recebe exceção crua: é ela que vai ouvir o texto, e ele
/// precisa de um motivo honesto para dizer que **não** registrou.
sdk.ClientToolResult voiceToolFailure(Object? failure) {
  final line = HomeErrorCopy.fromFailure(failure);
  return sdk.ClientToolResult.failure(line);
}

/// Resultado de um `Result` do domínio → retorno da tool.
sdk.ClientToolResult voiceToolFromResult<T>(
  Result<T> result,
  Map<String, dynamic> Function(T data) onSuccess,
) {
  switch (result) {
    case Success<T>(:final data):
      return sdk.ClientToolResult.success(onSuccess(data));
    case Failure<T>(:final failure):
      return voiceToolFailure(failure);
  }
}

/// `true`/`false` chegam como bool ou como texto, conforme o LLM.
bool? voiceToolBool(Object? raw) {
  if (raw is bool) return raw;
  if (raw is String) {
    final value = raw.trim().toLowerCase();
    if (value == 'true') return true;
    if (value == 'false') return false;
  }
  return null;
}

/// Texto de parâmetro limpo, ou `null` se vazio.
String? voiceToolString(Object? raw) {
  if (raw is! String) return null;
  final value = raw.trim();
  return value.isEmpty ? null : value;
}
