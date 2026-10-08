import 'dart:async';

import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import 'package:aura/features/caregiver_dashboard/domain/entities/care_signal.dart';
import 'package:aura/features/caregiver_dashboard/domain/entities/care_today.dart';
import 'package:aura/features/caregiver_dashboard/domain/repositories/care_feed_repository.dart';
import 'package:aura/features/caregiver_dashboard/domain/usecases/care_feed_usecases.dart';
import 'package:aura/features/caregiver_dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:aura/features/home_setup/domain/entities/home.dart';
import 'package:aura/features/home_setup/domain/repositories/home_repository.dart';
import 'package:aura/features/home_setup/domain/usecases/get_home_usecase.dart';
import 'package:aura/features/medications/domain/entities/medication.dart';
import 'package:aura/features/medications/domain/repositories/medication_repository.dart';
import 'package:aura/features/medications/domain/usecases/get_medications_usecase.dart';
import 'package:aura/features/wellbeing360/domain/entities/score.dart';
import 'package:aura/features/wellbeing360/domain/repositories/scores_repository.dart';
import 'package:aura/features/wellbeing360/domain/usecases/get_scores_usecase.dart';
import 'package:aura/shared/models/severity_level.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// O painel da família: o dia da Maria, o SOS em aberto e o "estou indo".
void main() {
  late _FakeFeed feed;
  late _FakeMeds meds;
  late _FakeScores scores;
  late _FakeHomes homes;
  late AuthSession session;
  late DashboardBloc bloc;

  // 12:40 local: a Losartana das 08:00 foi confirmada às 12:34, por voz.
  final start = DateTime(2026, 10, 7, 12, 40);
  late DateTime clock;

  setUp(() {
    clock = start;
    meds = _FakeMeds();
    scores = _FakeScores();
    homes = _FakeHomes();
    FlutterSecureStorage.setMockInitialValues({});
    session = AuthSession(TokenStore(const FlutterSecureStorage()))
      ..setHomeId('home-1');
    feed = _FakeFeed()
      ..signals = [
        CareSignal(
          id: 's1',
          type: 'adherence',
          source: 'voice',
          value: const {'medicationId': 'med-los', 'taken': true},
          capturedAt: DateTime(2026, 10, 7, 12, 34),
        ),
      ];
  });

  DashboardBloc build({Duration poll = Duration.zero}) => DashboardBloc(
        getHomeUseCase: GetHomeUseCase(homes),
        getScoresUseCase: GetScoresUseCase(scores),
        getMedicationsUseCase: GetMedicationsUseCase(meds),
        getCareSignalsUseCase: GetCareSignalsUseCase(feed),
        getActiveEmergencyUseCase: GetActiveEmergencyUseCase(feed),
        getEmergencyOutcomeUseCase: GetEmergencyOutcomeUseCase(feed),
        acknowledgeEmergencyUseCase: AcknowledgeEmergencyUseCase(feed),
        session: session,
        pollInterval: poll,
        now: () => clock,
      );

  Future<void> loaded(DashboardBloc b) async {
    b.add(const LoadDashboardEvent());
    await b.stream.firstWhere((s) => s.status == DashboardStatus.ready);
  }

  tearDown(() => bloc.close());

  test('carrega o dia: remédios de hoje e linha do tempo com a origem', () async {
    bloc = build();
    await loaded(bloc);

    final today = bloc.state.medicationsToday.single;
    expect(today.medication.name, 'Losartana');
    expect(today.status, DoseStatus.complete);
    expect(today.lastSource, ActivitySource.voice);
    expect(bloc.state.timeline.single.title, 'Maria confirmou Losartana');
    expect(bloc.state.patientFirstName, 'Maria');
    expect(bloc.state.activeEmergency, isNull);
    expect(bloc.state.needsAttention, isFalse);
  });

  test('a linha do tempo falhando não derruba o painel de risco', () async {
    feed.signalsFailure = const AppFailure.networkError(message: 'caiu');
    bloc = build();
    await loaded(bloc);

    expect(bloc.state.status, DashboardStatus.ready);
    expect(bloc.state.timeline, isEmpty);
    expect(bloc.state.topScore, isNotNull);
  });

  test('SOS já aberto na carga aparece e pede atenção', () async {
    feed.emergency = _ticket('em-1', 'dispatched');
    bloc = build();
    await loaded(bloc);

    expect(bloc.state.activeEmergency?.id, 'em-1');
    expect(bloc.state.needsAttention, isTrue);
  });

  test('o polling descobre um SOS novo e o tira quando deixa de estar aberto',
      () async {
    bloc = build(poll: const Duration(milliseconds: 30));
    await loaded(bloc);
    expect(bloc.state.activeEmergency, isNull);

    feed.emergency = _ticket('em-2', 'waiting_cancel');
    await bloc.stream.firstWhere((s) => s.activeEmergency?.id == 'em-2');

    // Deixou de estar aberto: a faixa não some calada — vira "encerrado" e só
    // sai depois do tempo de leitura.
    feed.emergency = null;
    await bloc.stream.firstWhere((s) => s.activeEmergency?.state == 'closed');

    clock = start.add(const Duration(minutes: 2));
    await bloc.stream.firstWhere((s) => s.activeEmergency == null);
  });

  test('"estou indo": confirma no servidor e a confirmação fica na tela',
      () async {
    feed.emergency = _ticket('em-3', 'dispatched');
    bloc = build(poll: const Duration(milliseconds: 30));
    await loaded(bloc);

    bloc.add(const AcknowledgeEmergencyEvent('em-3'));
    await bloc.stream.firstWhere((s) => s.activeEmergency?.state == 'acknowledged');

    expect(feed.acknowledged, ['em-3']);
    expect(bloc.state.acknowledging, isFalse);

    // O servidor já não a vê como aberta, mas o "você está indo" não some no
    // primeiro polling.
    feed.emergency = null;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(bloc.state.activeEmergency?.state, 'acknowledged');
  });

  test('falha ao confirmar: o alerta continua e a falha é dita', () async {
    feed.emergency = _ticket('em-4', 'dispatched');
    feed.ackFailure = const AppFailure.networkError(message: 'sem rede');
    bloc = build();
    await loaded(bloc);

    bloc.add(const AcknowledgeEmergencyEvent('em-4'));
    await bloc.stream.firstWhere((s) => s.acknowledgeFailed);

    expect(bloc.state.activeEmergency?.state, 'dispatched');
    expect(bloc.state.acknowledging, isFalse);
  });

  test('falha de rede no polling mantém a última leitura', () async {
    feed.emergency = _ticket('em-5', 'dispatched');
    bloc = build(poll: const Duration(milliseconds: 30));
    await loaded(bloc);

    feed.emergencyFailure = const AppFailure.networkError(message: 'caiu');
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(bloc.state.activeEmergency?.id, 'em-5');
  });

  group('falha não é lista vazia', () {
    test('remédios que não carregaram: o painel diz que não carregou, não '
        '"nenhum remédio" nem "tudo em ordem"', () async {
      meds.failure = const AppFailure.networkError(message: 'caiu');
      bloc = build();
      await loaded(bloc);

      expect(bloc.state.medicationsLoaded, isFalse);
      expect(bloc.state.todayAvailable, isFalse);
      expect(bloc.state.dataComplete, isFalse);
      // Sem os remédios o estado de dose não existe — e não vira "atrasada".
      expect(bloc.state.needsAttention, isFalse);
    });

    test('SOS que não deu para verificar: emergencyKnown falso, nunca "não '
        'há SOS"', () async {
      feed.emergencyFailure = const AppFailure.networkError(message: 'caiu');
      bloc = build();
      await loaded(bloc);

      expect(bloc.state.emergencyKnown, isFalse);
      expect(bloc.state.activeEmergency, isNull);
      expect(bloc.state.dataComplete, isFalse);
    });

    test('o polling recarrega os remédios que falharam na abertura', () async {
      meds.failure = const AppFailure.networkError(message: 'caiu');
      bloc = build(poll: const Duration(milliseconds: 30));
      await loaded(bloc);
      expect(bloc.state.medicationsLoaded, isFalse);

      meds.failure = null;
      await bloc.stream.firstWhere((s) => s.medicationsLoaded);

      expect(bloc.state.medicationsToday, isNotEmpty);
      expect(bloc.state.dataComplete, isTrue);
    });
  });

  group('dados desatualizados', () {
    test('duas falhas seguidas do polling avisam; uma leitura boa limpa o '
        'aviso e guarda a hora', () async {
      bloc = build(poll: const Duration(milliseconds: 30));
      await loaded(bloc);
      final syncedAt = bloc.state.lastSyncAt;
      expect(syncedAt, start);

      clock = start.add(const Duration(minutes: 3));
      feed.emergencyFailure = const AppFailure.networkError(message: 'caiu');
      await bloc.stream.firstWhere((s) => s.staleSince != null);

      expect(bloc.state.dataComplete, isFalse);
      // O aviso cita a última leitura que DEU CERTO, não a hora da falha.
      expect(bloc.state.lastSyncAt, syncedAt);

      feed.emergencyFailure = null;
      await bloc.stream.firstWhere((s) => s.staleSince == null);
      expect(bloc.state.dataComplete, isTrue);
      expect(bloc.state.lastSyncAt, isNot(syncedAt));
    });
  });

  group('correções da 2ª revisão', () {
    test('os sinais vêm com recorte de data: a linha do tempo desde ontem e as '
        'doses, em chamada PRÓPRIA, desde hoje', () async {
      bloc = build();
      await loaded(bloc);

      expect(feed.sinceRequested, [DateTime(2026, 10, 6), DateTime(2026, 10, 7)]);
      expect(feed.typesRequested, [null, 'adherence']);
    });

    test('a página de sinais cheia de leituras do relógio NÃO transforma dose '
        'tomada em "atrasada"', () async {
      // A chamada geral só devolve ruído; a dose está na chamada de adesão.
      feed.timelineOverride = [
        for (var i = 0; i < 5; i++)
          CareSignal(
            id: 'w$i',
            type: 'vitals',
            source: 'wearable',
            value: const {'steps': 100},
            capturedAt: DateTime(2026, 10, 7, 12, 30 + i),
          ),
      ];
      bloc = build();
      await loaded(bloc);

      expect(bloc.state.medicationsToday.single.status, DoseStatus.complete);
      expect(bloc.state.needsAttention, isFalse);
    });

    test('recarregar com o painel na tela mantém o SOS mesmo se a casa falhar',
        () async {
      feed.emergency = _ticket('em-12', 'dispatched');
      bloc = build();
      await loaded(bloc);
      expect(bloc.state.activeEmergency?.id, 'em-12');

      homes.failure = const AppFailure.networkError(message: 'caiu');
      bloc.add(const LoadDashboardEvent());
      await bloc.stream.firstWhere((s) => s.staleSince != null);

      // Nada de "carregando" nem "erro" em tela cheia: o alerta e o botão ficam.
      expect(bloc.state.status, DashboardStatus.ready);
      expect(bloc.state.activeEmergency?.isOpen, isTrue);
    });

    test('um desfecho encerra a falha antiga do "estou indo": as duas frases '
        'não coexistem', () async {
      feed.emergency = _ticket('em-13', 'dispatched');
      feed.ackFailure = const AppFailure.networkError(message: 'caiu');
      bloc = build(poll: const Duration(milliseconds: 30));
      await loaded(bloc);

      bloc.add(const AcknowledgeEmergencyEvent('em-13'));
      await bloc.stream.firstWhere((s) => s.acknowledgeFailed);

      // Outra cuidadora confirma enquanto isso.
      feed.emergency = null;
      feed.outcome = ActiveEmergency(
        id: 'em-13',
        state: 'acknowledged',
        createdAt: DateTime(2026, 10, 7, 12, 38),
        acknowledgedByName: 'Bruno',
      );
      await bloc.stream
          .firstWhere((s) => s.activeEmergency?.state == 'acknowledged');

      expect(bloc.state.acknowledgeFailed, isFalse);
    });

    test('risco que não carregou: scoresLoaded falso e "tudo em ordem" não vale',
        () async {
      scores.failure = const AppFailure.networkError(message: 'caiu');
      bloc = build();
      await loaded(bloc);

      expect(bloc.state.scoresLoaded, isFalse);
      expect(bloc.state.dataComplete, isFalse);
      expect(bloc.state.topScore, isNull);
    });

    test('a primeira falha ao verificar o SOS já vira "não consegui verificar"',
        () async {
      bloc = build(poll: const Duration(milliseconds: 30));
      await loaded(bloc);
      expect(bloc.state.emergencyKnown, isTrue);

      feed.emergencyFailure = const AppFailure.networkError(message: 'caiu');
      await bloc.stream.firstWhere((s) => !s.emergencyKnown);

      expect(bloc.state.activeEmergency, isNull);
      expect(bloc.state.dataComplete, isFalse);
    });

    test('polling lento que começou ANTES do "estou indo" não desfaz a '
        'confirmação quando responde depois', () async {
      feed.emergency = _ticket('em-10', 'dispatched');
      bloc = build();
      await loaded(bloc);

      // O polling começa e fica esperando a rede...
      feed.emergencyGate = Completer<void>();
      bloc.add(const DashboardPolledEvent());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // ...a Ana toca "estou indo" e o servidor confirma...
      bloc.add(const AcknowledgeEmergencyEvent('em-10'));
      await bloc.stream
          .firstWhere((s) => s.activeEmergency?.state == 'acknowledged');

      // ...e só então o polling responde, com a leitura ANTERIOR à confirmação.
      feed.emergencyGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.activeEmergency?.state, 'acknowledged');
      expect(bloc.state.activeEmergency?.isOpen, isFalse);
      expect(bloc.state.acknowledging, isFalse);
    });

    test('"encerrado" reconsulta o desfecho: a rede volta e a faixa diz quem '
        'estava indo', () async {
      feed.emergency = _ticket('em-11', 'dispatched');
      bloc = build(poll: const Duration(milliseconds: 30));
      await loaded(bloc);

      feed.emergency = null;
      feed.outcomeFailure = const AppFailure.networkError(message: 'caiu');
      await bloc.stream.firstWhere((s) => s.activeEmergency?.state == 'closed');

      feed.outcomeFailure = null;
      feed.outcome = ActiveEmergency(
        id: 'em-11',
        state: 'acknowledged',
        createdAt: DateTime(2026, 10, 7, 12, 38),
        acknowledgedByName: 'Bruno',
      );
      await bloc.stream
          .firstWhere((s) => s.activeEmergency?.state == 'acknowledged');

      expect(bloc.state.activeEmergency?.acknowledgedByName, 'Bruno');
    });
  });

  group('desfecho do SOS', () {
    test('"estou indo" mantém o horário do pedido (o ack não o devolve)',
        () async {
      feed.emergency = _ticket('em-6', 'dispatched');
      bloc = build();
      await loaded(bloc);

      bloc.add(const AcknowledgeEmergencyEvent('em-6'));
      await bloc.stream.firstWhere((s) => s.activeEmergency?.state == 'acknowledged');

      expect(bloc.state.activeEmergency?.createdAt, DateTime(2026, 10, 7, 12, 38));
    });

    test('outra cuidadora confirmou: a faixa não some calada, diz quem', () async {
      feed.emergency = _ticket('em-7', 'dispatched');
      bloc = build(poll: const Duration(milliseconds: 30));
      await loaded(bloc);

      feed.emergency = null;
      feed.outcome = ActiveEmergency(
        id: 'em-7',
        state: 'acknowledged',
        createdAt: DateTime(2026, 10, 7, 12, 38),
        acknowledgedByName: 'Bruno',
      );
      await bloc.stream.firstWhere((s) => s.activeEmergency?.state == 'acknowledged');

      expect(bloc.state.activeEmergency?.acknowledgedByName, 'Bruno');
      expect(bloc.state.activeEmergency?.isOpen, isFalse);
      // Já não pede atenção: está resolvido.
      expect(bloc.state.needsAttention, isFalse);
    });

    test('a Maria cancelou: a faixa vira "cancelou", e some depois do tempo',
        () async {
      feed.emergency = _ticket('em-8', 'waiting_cancel');
      bloc = build(poll: const Duration(milliseconds: 30));
      await loaded(bloc);

      feed.emergency = null;
      feed.outcome = ActiveEmergency(
        id: 'em-8',
        state: 'cancelled',
        createdAt: DateTime(2026, 10, 7, 12, 38),
      );
      await bloc.stream.firstWhere((s) => s.activeEmergency?.state == 'cancelled');

      clock = start.add(const Duration(minutes: 2));
      await bloc.stream.firstWhere((s) => s.activeEmergency == null);
    });

    test('sem conseguir saber como terminou: "encerrado", sem inventar', () async {
      feed.emergency = _ticket('em-9', 'dispatched');
      bloc = build(poll: const Duration(milliseconds: 30));
      await loaded(bloc);

      feed.emergency = null;
      feed.outcomeFailure = const AppFailure.networkError(message: 'caiu');
      await bloc.stream.firstWhere((s) => s.activeEmergency?.state == 'closed');

      expect(bloc.state.activeEmergency?.createdAt, DateTime(2026, 10, 7, 12, 38));
    });
  });
}

ActiveEmergency _ticket(String id, String state) => ActiveEmergency(
      id: id,
      state: state,
      createdAt: DateTime(2026, 10, 7, 12, 38),
    );

class _FakeFeed implements CareFeedRepository {
  List<CareSignal> signals = [];
  ActiveEmergency? emergency;
  Object? signalsFailure;
  Object? emergencyFailure;
  Object? ackFailure;
  ActiveEmergency? outcome;
  Object? outcomeFailure;
  final List<String> acknowledged = [];
  final List<DateTime?> sinceRequested = [];
  final List<String?> typesRequested = [];

  /// O que a chamada SEM tipo devolve (simula a página cheia de leituras do relógio).
  List<CareSignal>? timelineOverride;

  @override
  Future<Result<List<CareSignal>>> getSignals(String homeId,
      {int limit = 200, DateTime? since, String? type}) async {
    sinceRequested.add(since);
    typesRequested.add(type);
    if (signalsFailure != null) return Failure(signalsFailure);
    if (type != null) {
      return Success([for (final s in signals) if (s.type == type) s]);
    }
    // Sem tipo: a página "mais nova" enche de leituras do relógio e a dose cai fora dela.
    return Success(timelineOverride ?? signals);
  }

  /// Segura a resposta do `/emergencies/active` até ser liberada: simula rede
  /// lenta, em que o polling começa ANTES do toque em "estou indo" e responde
  /// DEPOIS dele.
  Completer<void>? emergencyGate;

  @override
  Future<Result<ActiveEmergency?>> getActiveEmergency(String homeId) async {
    final snapshot = emergency;
    final gate = emergencyGate;
    if (gate != null) await gate.future;
    if (emergencyFailure != null) return Failure(emergencyFailure);
    return Success(gate != null ? snapshot : emergency);
  }

  @override
  Future<Result<ActiveEmergency>> getEmergencyOutcome(
      String emergencyId) async {
    if (outcomeFailure != null) return Failure(outcomeFailure);
    return Success(outcome ??
        ActiveEmergency(
          id: emergencyId,
          state: 'closed',
          createdAt: DateTime(2026, 10, 7, 12, 38),
        ));
  }

  @override
  Future<Result<ActiveEmergency>> acknowledge(String emergencyId) async {
    if (ackFailure != null) return Failure(ackFailure);
    acknowledged.add(emergencyId);
    return Success(ActiveEmergency(
      id: emergencyId,
      state: 'acknowledged',
      createdAt: DateTime(2026, 10, 7, 12, 38),
      acknowledgedByName: 'Ana',
    ));
  }
}

class _FakeHomes implements HomeRepository {
  Object? failure;

  @override
  Future<Result<HomeDetail>> getHome(String homeId) async => failure != null
      ? Failure(failure)
      : const Success(HomeDetail(
        home: Home(
            id: 'home-1',
            label: 'Casa da Maria',
            address: 'Av. Paulista',
            lat: null,
            lng: null),
        patientName: 'Maria S.',
        checklist: {},
      ));

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeScores implements ScoresRepository {
  Object? failure;

  @override
  Future<Result<List<Score>>> getScores(String homeId) async => failure != null
      ? Failure(failure)
      : const Success([
        Score(
          scoreId: 'sc-1',
          dimension: WellbeingDimensionType.sleep,
          level: SeverityLevel.ok,
          score: 0.2,
          factors: [],
          weights: [],
          explanation: '',
        ),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeMeds implements MedicationRepository {
  Object? failure;

  @override
  Future<Result<List<Medication>>> getMedications(String homeId) async =>
      failure != null
          ? Failure(failure)
          : const Success([
        Medication(
            id: 'med-los',
            homeId: 'home-1',
            name: 'Losartana',
            dosage: '50mg',
            times: ['08:00']),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
