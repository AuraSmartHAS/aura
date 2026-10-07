import 'package:aura/core/session/auth_session.dart';
import 'package:aura/features/medications/domain/usecases/confirm_dose_usecase.dart';
import 'package:aura/features/medications/domain/usecases/get_medications_usecase.dart';
import 'package:aura/features/sos/domain/usecases/trigger_emergency_usecase.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart' as sdk;

import '../../domain/usecases/register_symptom_usecase.dart';
import 'confirm_medication_tool.dart';
import 'list_medications_tool.dart';
import 'register_symptom_tool.dart';
import 'trigger_sos_tool.dart';
import 'voice_sos_gateway.dart';

/// As quatro client tools do agente de voz, por nome — o mesmo nome cadastrado
/// no painel do ElevenLabs.
Map<String, sdk.ClientTool> buildVoiceClientTools({
  required RegisterSymptomUseCase registerSymptom,
  required GetMedicationsUseCase getMedications,
  required ConfirmDoseUseCase confirmDose,
  required TriggerEmergencyUseCase triggerEmergency,
  required AuthSession session,
  required VoiceSosGateway sosGateway,
}) {
  return {
    RegisterSymptomTool.name: RegisterSymptomTool(registerSymptom, session),
    ListMedicationsTool.name: ListMedicationsTool(getMedications, session),
    ConfirmMedicationTool.name: ConfirmMedicationTool(confirmDose),
    TriggerSosTool.name: TriggerSosTool(triggerEmergency, sosGateway),
  };
}
