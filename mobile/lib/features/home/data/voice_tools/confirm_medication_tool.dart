import 'package:aura/features/medications/domain/usecases/confirm_dose_usecase.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart' as sdk;

import 'voice_tool_support.dart';

/// `confirm_medication`: registra a dose tomada (ou não) de um remédio.
///
/// O servidor ainda não deduplica a confirmação (TASK-007), então o aparelho
/// segura a repetição: o mesmo remédio com a mesma resposta dentro da janela
/// não vai duas vezes — senão a adesão e o estoque contariam em dobro.
class ConfirmMedicationTool implements sdk.ClientTool {
  ConfirmMedicationTool(
    this._confirmDose, {
    required String? Function() sourceFor,
    DateTime Function()? now,
    this.dedupeWindow = const Duration(seconds: 60),
  })  : _sourceFor = sourceFor,
        _now = now ?? DateTime.now;

  static const String name = 'confirm_medication';

  final ConfirmDoseUseCase _confirmDose;

  /// Origem a declarar ao servidor. `voice` só vale para a conta da paciente; para
  /// qualquer outra o servidor recusaria (400) e a dose falada se perderia — então
  /// a tool cai para o padrão (`self_report`) em vez de não registrar nada.
  final String? Function() _sourceFor;
  final DateTime Function() _now;
  final Duration dedupeWindow;

  final Map<String, DateTime> _recent = {};

  @override
  Future<sdk.ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    final id = voiceToolString(parameters['medicationId']);
    if (id == null) {
      return sdk.ClientToolResult.failure(
        'Falta o id do remédio. Consulte a lista antes de confirmar.',
      );
    }
    final taken = voiceToolBool(parameters['taken']) ?? true;

    final key = '$id|$taken';
    final now = _now();
    final last = _recent[key];
    if (last != null && now.difference(last) < dedupeWindow) {
      return sdk.ClientToolResult.success({
        'confirmed': true,
        'alreadyConfirmed': true,
        'taken': taken,
      });
    }

    final result = await _confirmDose(id, taken: taken, source: _sourceFor());
    final output = voiceToolFromResult(
      result,
      (dose) => {
        'confirmed': true,
        'taken': dose.taken,
        if (dose.stockDoses != null) 'stockDoses': dose.stockDoses,
      },
    );
    if (output.success) _recent[key] = now;
    return output;
  }
}
