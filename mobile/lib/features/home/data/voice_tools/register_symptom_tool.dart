import 'package:aura/core/session/auth_session.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart' as sdk;

import '../../domain/usecases/register_symptom_usecase.dart';
import 'voice_tool_support.dart';

/// `register_symptom`: grava o relato falado como sinal `source=voice`.
class RegisterSymptomTool implements sdk.ClientTool {
  RegisterSymptomTool(this._registerSymptom, this._session);

  static const String name = 'register_symptom';

  /// Dimensões aceitas pelo servidor (`SignalType`).
  static const Set<String> allowedTypes = {
    'mobility',
    'sleep',
    'cognition',
    'mood',
    'environment',
    'adherence',
    'vitals',
  };

  static final RegExp _slug = RegExp(r'^[a-z0-9_]{1,40}$');
  static const int _maxNote = 200;

  final RegisterSymptomUseCase _registerSymptom;
  final AuthSession _session;

  @override
  Future<sdk.ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    final type = voiceToolString(parameters['type'])?.toLowerCase();
    final event = voiceToolString(parameters['event'])?.toLowerCase();
    if (type == null || !allowedTypes.contains(type)) {
      return sdk.ClientToolResult.failure(
        'Tipo inválido. Use um destes: ${allowedTypes.join(', ')}.',
      );
    }
    if (event == null || !_slug.hasMatch(event)) {
      return sdk.ClientToolResult.failure(
        'Evento inválido. Use palavra curta em minúsculas com underscore.',
      );
    }

    final homeId = _session.homeId;
    if (homeId == null) {
      return sdk.ClientToolResult.failure(
        'Não achei a casa deste aparelho, então o relato não foi registrado.',
      );
    }

    final place = voiceToolString(parameters['place'])?.toLowerCase();
    var note = voiceToolString(parameters['note']);
    if (note != null && note.length > _maxNote) {
      note = note.substring(0, _maxNote);
    }

    final value = <String, dynamic>{
      'event': event,
      if (place != null && _slug.hasMatch(place)) 'place': place,
      if (note != null) 'note': note,
    };

    final result = await _registerSymptom(
      homeId: homeId,
      type: type,
      value: value,
    );
    return voiceToolFromResult<String>(
      result,
      (signalId) => {'registered': true, 'signalId': signalId},
    );
  }
}
