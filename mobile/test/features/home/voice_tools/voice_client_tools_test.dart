
import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import 'package:aura/features/home/data/voice_tools/voice_client_tools.dart';
import 'package:aura/features/home/data/voice_tools/voice_sos_gateway.dart';
import 'package:aura/features/home/domain/repositories/symptom_repository.dart';
import 'package:aura/features/home/domain/usecases/register_symptom_usecase.dart';
import 'package:aura/features/medications/domain/entities/medication.dart';
import 'package:aura/features/medications/domain/repositories/medication_repository.dart';
import 'package:aura/features/medications/domain/usecases/confirm_dose_usecase.dart';
import 'package:aura/features/medications/domain/usecases/get_medications_usecase.dart';
import 'package:aura/features/sos/domain/entities/emergency.dart';
import 'package:aura/features/sos/domain/repositories/emergency_repository.dart';
import 'package:aura/features/sos/domain/usecases/trigger_emergency_usecase.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart' as sdk;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// As quatro client tools do agente de voz. A regra que o arquivo inteiro
/// prende: **só há sucesso quando o servidor respondeu sucesso**.
void main() {
  late _FakeSymptoms symptoms;
  late _FakeMedications meds;
  late _FakeEmergencies emergencies;
  late VoiceSosGateway gateway;
  late AuthSession session;
  late Map<String, sdk.ClientTool> tools;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    session = AuthSession(TokenStore(const FlutterSecureStorage()))
      ..setHomeId('home-1');
    symptoms = _FakeSymptoms();
    meds = _FakeMedications();
    emergencies = _FakeEmergencies();
    gateway = VoiceSosGateway();
    addTearDown(gateway.dispose);
    tools = buildVoiceClientTools(
      registerSymptom: RegisterSymptomUseCase(symptoms),
      getMedications: GetMedicationsUseCase(meds),
      confirmDose: ConfirmDoseUseCase(meds),
      triggerEmergency: TriggerEmergencyUseCase(emergencies),
      session: session,
      sosGateway: gateway,
    );
  });

  Future<sdk.ClientToolResult> run(String name, Map<String, dynamic> params) async =>
      (await tools[name]!.execute(params))!;

  test('os nomes batem com os cadastrados no painel do ElevenLabs', () {
    expect(tools.keys, {
      'register_symptom',
      'list_medications',
      'confirm_medication',
      'trigger_sos',
    });
  });

  group('register_symptom', () {
    test('grava sinal de voz e devolve o id do servidor', () async {
      final result = await run('register_symptom', {
        'type': 'Mobility',
        'event': 'near_fall',
        'place': 'bathroom',
        'note': 'quase caí',
      });

      expect(result.success, isTrue);
      expect(result.data, {'registered': true, 'signalId': 'sig-1'});
      expect(symptoms.calls.single.homeId, 'home-1');
      expect(symptoms.calls.single.type, 'mobility');
      expect(symptoms.calls.single.value,
          {'event': 'near_fall', 'place': 'bathroom', 'note': 'quase caí'});
    });

    test('tipo fora do enum não chega ao servidor', () async {
      final result =
          await run('register_symptom', {'type': 'fever', 'event': 'x'});

      expect(result.success, isFalse);
      expect(symptoms.calls, isEmpty);
    });

    test('evento fora do formato não chega ao servidor', () async {
      final result = await run(
          'register_symptom', {'type': 'mood', 'event': 'Estou triste!'});

      expect(result.success, isFalse);
      expect(symptoms.calls, isEmpty);
    });

    test('sem casa no aparelho não finge registrar', () async {
      final empty = AuthSession(TokenStore(const FlutterSecureStorage()));
      tools = buildVoiceClientTools(
        registerSymptom: RegisterSymptomUseCase(symptoms),
        getMedications: GetMedicationsUseCase(meds),
        confirmDose: ConfirmDoseUseCase(meds),
        triggerEmergency: TriggerEmergencyUseCase(emergencies),
        session: empty,
        sosGateway: gateway,
      );

      final result =
          await run('register_symptom', {'type': 'mood', 'event': 'sadness'});

      expect(result.success, isFalse);
      expect(symptoms.calls, isEmpty);
    });

    test('falha de rede vira erro, nunca "registered"', () async {
      symptoms.failure = const AppFailure.networkError(message: 'Sem conexão');

      final result =
          await run('register_symptom', {'type': 'mood', 'event': 'sadness'});

      expect(result.success, isFalse);
      expect(result.data, isNull);
      expect(result.error, isNotEmpty);
    });
  });

  group('list_medications', () {
    test('devolve só os ativos, com id para confirmar', () async {
      final result = await run('list_medications', {});

      expect(result.success, isTrue);
      final list = (result.data as Map)['medications'] as List;
      expect(list, hasLength(1));
      expect(list.single, containsPair('id', 'med-1'));
      expect(list.single, containsPair('name', 'Levodopa'));
    });

    test('falha do servidor vira erro', () async {
      meds.failure = const AppFailure.unauthorized(message: 'expirou');

      final result = await run('list_medications', {});

      expect(result.success, isFalse);
    });
  });

  group('confirm_medication', () {
    test('confirma a dose e devolve o estoque do servidor', () async {
      final result = await run('confirm_medication', {'medicationId': 'med-1'});

      expect(result.success, isTrue);
      expect(result.data,
          {'confirmed': true, 'taken': true, 'stockDoses': 9});
      expect(meds.confirms, [('med-1', true)]);
    });

    test('taken aceita texto "false"', () async {
      await run('confirm_medication',
          {'medicationId': 'med-1', 'taken': 'false'});

      expect(meds.confirms, [('med-1', false)]);
    });

    test('repetir na janela não chama a API de novo', () async {
      await run('confirm_medication', {'medicationId': 'med-1'});
      final second =
          await run('confirm_medication', {'medicationId': 'med-1'});

      expect(meds.confirms, hasLength(1));
      expect(second.success, isTrue);
      expect((second.data as Map)['alreadyConfirmed'], isTrue);
    });

    test('falha não conta como confirmada: a nova tentativa vai ao servidor',
        () async {
      meds.confirmFailure = const AppFailure.networkError(message: 'caiu');
      final first =
          await run('confirm_medication', {'medicationId': 'med-1'});
      meds.confirmFailure = null;
      final second =
          await run('confirm_medication', {'medicationId': 'med-1'});

      expect(first.success, isFalse);
      expect(second.success, isTrue);
      // O fake só guarda o que deu certo: a falha não entrou, a nova tentativa sim.
      expect(meds.confirms, [('med-1', true)]);
    });

    test('sem id não chama o servidor', () async {
      final result = await run('confirm_medication', {});

      expect(result.success, isFalse);
      expect(meds.confirms, isEmpty);
    });
  });

  group('trigger_sos', () {
    test('sem confirmação verbal não aciona nada', () async {
      final shown = <void>[];
      final sub = gateway.requests.listen(shown.add);
      addTearDown(sub.cancel);

      final result = await run('trigger_sos', {'confirmed': false});
      await Future<void>.delayed(Duration.zero);

      expect(result.success, isFalse);
      expect(emergencies.triggers, isEmpty);
      expect(shown, isEmpty);
    });

    test('confirmado: pede socorro por voz, devolve o que se pode prometer e '
        'sobe a folha', () async {
      final shown = <void>[];
      final sub = gateway.requests.listen(shown.add);
      addTearDown(sub.cancel);

      final result = await run('trigger_sos', {'confirmed': true});
      await Future<void>.delayed(Duration.zero);

      expect(emergencies.triggers, [EmergencyChannel.voice]);
      expect(result.success, isTrue);
      final data = result.data as Map;
      expect(data['registered'], isTrue);
      expect(data['state'], 'waiting_cancel');
      expect(data['cancelWindowSeconds'], 5);
      expect(data['canPromiseAlert'], isFalse);
      expect(data['simulated'], isTrue);
      expect(data['primaryContactName'], 'Ana');
      expect(shown, hasLength(1));
    });

    test('falha ao pedir socorro vira erro e ainda sobe a folha (botão de '
        'ligar)', () async {
      emergencies.failure = const AppFailure.networkError(message: 'sem rede');
      final shown = <void>[];
      final sub = gateway.requests.listen(shown.add);
      addTearDown(sub.cancel);

      final result = await run('trigger_sos', {'confirmed': true});
      await Future<void>.delayed(Duration.zero);

      expect(result.success, isFalse);
      expect(result.data, isNull);
      expect(shown, hasLength(1));
    });
  });
}

class _SymptomCall {
  _SymptomCall(this.homeId, this.type, this.value);
  final String homeId;
  final String type;
  final Map<String, dynamic> value;
}

class _FakeSymptoms implements SymptomRepository {
  final List<_SymptomCall> calls = [];
  Object? failure;

  @override
  Future<Result<String>> register({
    required String homeId,
    required String type,
    required Map<String, dynamic> value,
  }) async {
    if (failure != null) return Failure(failure);
    calls.add(_SymptomCall(homeId, type, value));
    return const Success('sig-1');
  }
}

class _FakeMedications implements MedicationRepository {
  Object? failure;
  Object? confirmFailure;
  final List<(String, bool)> confirms = [];

  @override
  Future<Result<List<Medication>>> getMedications(String homeId) async {
    if (failure != null) return Failure(failure);
    return const Success([
      Medication(
        id: 'med-1',
        homeId: 'home-1',
        name: 'Levodopa',
        dosage: '100mg',
        times: ['08:00', '20:00'],
        stockDoses: 10,
      ),
      Medication(id: 'med-2', homeId: 'home-1', name: 'Velho', active: false),
    ]);
  }

  @override
  Future<Result<DoseConfirmation>> confirmDose(String id,
      {required bool taken}) async {
    if (confirmFailure != null) return Failure(confirmFailure);
    confirms.add((id, taken));
    return Success(
        DoseConfirmation(signalId: 'sig-$id', taken: taken, stockDoses: 9));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeEmergencies implements EmergencyRepository {
  Object? failure;
  final List<EmergencyChannel> triggers = [];

  @override
  Future<Result<EmergencyTicket>> trigger(
      {required EmergencyChannel channel}) async {
    if (failure != null) return Failure(failure);
    triggers.add(channel);
    return const Success(EmergencyTicket(
      id: 'em-1',
      state: EmergencyState.waitingCancel,
      cancelWindowSeconds: 5,
      canPromiseAlert: false,
      simulated: true,
      primaryContactName: 'Ana',
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
