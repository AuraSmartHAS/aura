import 'package:aura/core/session/auth_session.dart';
import 'package:aura/features/medications/domain/usecases/get_medications_usecase.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart' as sdk;

import 'voice_tool_support.dart';

/// `list_medications`: remédios ativos da casa. Só leitura.
class ListMedicationsTool implements sdk.ClientTool {
  ListMedicationsTool(this._getMedications, this._session);

  static const String name = 'list_medications';

  final GetMedicationsUseCase _getMedications;
  final AuthSession _session;

  @override
  Future<sdk.ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    final homeId = _session.homeId;
    if (homeId == null) {
      return sdk.ClientToolResult.failure(
        'Não achei a casa deste aparelho, então não consegui ver os remédios.',
      );
    }

    final result = await _getMedications(homeId);
    return voiceToolFromResult(result, (medications) {
      return {
        'medications': [
          for (final m in medications.where((m) => m.active))
            {
              'id': m.id,
              'name': m.name,
              if (m.dosage != null) 'dosage': m.dosage,
              'schedule': m.times,
              if (m.stockDoses != null) 'stockDoses': m.stockDoses,
            },
        ],
      };
    });
  }
}
