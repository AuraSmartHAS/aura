import 'package:aura/core/errors/result.dart';
import 'package:aura/features/sos/domain/entities/emergency.dart';
import 'package:aura/features/sos/domain/usecases/trigger_emergency_usecase.dart';
import 'package:aura/features/sos/presentation/sos_copy.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart' as sdk;

import '../../presentation/home_error_copy.dart';
import 'voice_sos_gateway.dart';
import 'voice_tool_support.dart';

/// `trigger_sos`: pede socorro pelo canal de voz, depois da confirmação verbal.
///
/// O retorno repassa o que o servidor diz poder ser prometido
/// (`canPromiseAlert`, `simulated`, `spokenMessage`): quem decide o que o
/// agente pode afirmar é a API, não o modelo.
class TriggerSosTool implements sdk.ClientTool {
  TriggerSosTool(this._trigger, this._gateway);

  static const String name = 'trigger_sos';

  final TriggerEmergencyUseCase _trigger;
  final VoiceSosGateway _gateway;

  @override
  Future<sdk.ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    if (voiceToolBool(parameters['confirmed']) != true) {
      return sdk.ClientToolResult.failure(
        'Sem confirmação verbal da pessoa. Pergunte se ela quer pedir ajuda '
        'e só então acione.',
      );
    }

    final result = await _trigger(channel: EmergencyChannel.voice);

    // Sucesso ou falha, a folha sobe: com sucesso ela traz a janela de
    // cancelamento; com falha, o botão de ligar.
    _gateway.show();

    switch (result) {
      case Success<EmergencyTicket>(:final data):
        return sdk.ClientToolResult.success({
          'registered': true,
          'state': _wire(data.state),
          'cancelWindowSeconds': data.cancelWindowSeconds,
          'canPromiseAlert': data.canPromiseAlert,
          'simulated': data.simulated,
          'throttled': data.throttled,
          if (data.primaryContactName != null)
            'primaryContactName': data.primaryContactName,
          if (data.spokenMessage != null) 'spokenMessage': data.spokenMessage,
        });
      case Failure<EmergencyTicket>(:final failure):
        final line = failure is DeviceNotPairedFailure
            ? SosCopy.noPairedHome
            : HomeErrorCopy.forSos(failure);
        return sdk.ClientToolResult.failure(line);
    }
  }

  static String _wire(EmergencyState state) {
    switch (state) {
      case EmergencyState.waitingCancel:
        return 'waiting_cancel';
      case EmergencyState.dispatched:
        return 'dispatched';
      case EmergencyState.escalated:
        return 'escalated';
      case EmergencyState.acknowledged:
        return 'acknowledged';
      case EmergencyState.cancelled:
        return 'cancelled';
      case EmergencyState.throttled:
        return 'throttled';
      case EmergencyState.unknown:
        return 'unknown';
    }
  }
}
