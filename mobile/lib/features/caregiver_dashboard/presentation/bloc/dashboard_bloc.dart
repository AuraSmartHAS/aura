import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:aura/core/errors/failure_messages.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/features/home_setup/domain/entities/home.dart';
import 'package:aura/features/home_setup/domain/usecases/get_home_usecase.dart';
import 'package:aura/features/medications/domain/entities/medication.dart';
import 'package:aura/features/medications/domain/usecases/get_medications_usecase.dart';
import 'package:aura/features/wellbeing360/domain/entities/score.dart';
import 'package:aura/features/wellbeing360/domain/usecases/get_scores_usecase.dart';
import 'package:aura/shared/models/severity_level.dart';

import '../../domain/care_today_builder.dart';
import '../../domain/entities/care_signal.dart';
import '../../domain/entities/care_today.dart';
import '../../domain/usecases/care_feed_usecases.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

/// O que fazer com a faixa de SOS depois de perguntar ao servidor. Decidido
/// ANTES de aplicar: a decisão pode esperar a rede (consultar o desfecho), e o
/// que se aplica é sempre sobre o estado mais novo.
class _EmergencyDecision {
  const _EmergencyDecision({
    this.set,
    this.clear = false,
    this.restartLinger = false,
    this.stopLinger = false,
  });

  final ActiveEmergency? set;
  final bool clear;
  final bool restartLinger;
  final bool stopLinger;
}

/// Aggregates the caregiver "status of the day": home detail + highest risk +
/// today's medication, what Maria said and did, and any open SOS.
/// Consumes use cases exported by other features (no direct data coupling),
/// per the cross-feature rule.
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({
    required GetHomeUseCase getHomeUseCase,
    required GetScoresUseCase getScoresUseCase,
    required GetMedicationsUseCase getMedicationsUseCase,
    required GetCareSignalsUseCase getCareSignalsUseCase,
    required GetActiveEmergencyUseCase getActiveEmergencyUseCase,
    required GetEmergencyOutcomeUseCase getEmergencyOutcomeUseCase,
    required AcknowledgeEmergencyUseCase acknowledgeEmergencyUseCase,
    required AuthSession session,
    this.pollInterval = const Duration(seconds: 5),
    DateTime Function()? now,
  })  : _getHomeUseCase = getHomeUseCase,
        _getScoresUseCase = getScoresUseCase,
        _getMedicationsUseCase = getMedicationsUseCase,
        _getCareSignalsUseCase = getCareSignalsUseCase,
        _getActiveEmergencyUseCase = getActiveEmergencyUseCase,
        _getEmergencyOutcomeUseCase = getEmergencyOutcomeUseCase,
        _acknowledgeEmergencyUseCase = acknowledgeEmergencyUseCase,
        _session = session,
        _now = now ?? DateTime.now,
        super(const DashboardState.loading()) {
    on<LoadDashboardEvent>(_onLoad);
    on<DashboardPolledEvent>(_onPolled);
    on<AcknowledgeEmergencyEvent>(_onAcknowledge);
  }

  final GetHomeUseCase _getHomeUseCase;
  final GetScoresUseCase _getScoresUseCase;
  final GetMedicationsUseCase _getMedicationsUseCase;
  final GetCareSignalsUseCase _getCareSignalsUseCase;
  final GetActiveEmergencyUseCase _getActiveEmergencyUseCase;
  final GetEmergencyOutcomeUseCase _getEmergencyOutcomeUseCase;
  final AcknowledgeEmergencyUseCase _acknowledgeEmergencyUseCase;
  final AuthSession _session;
  final DateTime Function() _now;

  /// De quanto em quanto tempo se pergunta ao servidor por SOS e sinais novos.
  /// `Duration.zero` desliga (teste).
  final Duration pollInterval;

  Timer? _pollTimer;
  List<Medication> _medications = const [];
  List<CareSignal> _signals = const [];

  /// Confirmações de dose (type=adherence) — chamada PRÓPRIA: o status de dose não pode depender
  /// de a confirmação caber entre os N sinais mais novos, que leituras do relógio enchem.
  List<CareSignal> _adherence = const [];
  bool _polling = false;

  /// Falhas seguidas do polling; a partir de [_staleAfterFailures] a tela avisa
  /// que o que mostra pode estar velho.
  int _pollFailures = 0;
  static const int _staleAfterFailures = 2;

  /// Quando o SOS passou a um estado final (esta pessoa disse "estou indo", ou
  /// descobrimos que outra confirmou / a Maria cancelou): o desfecho fica na
  /// tela por um instante em vez de sumir no primeiro polling.
  DateTime? _resolvedAt;
  static const Duration _finalLinger = Duration(seconds: 45);

  /// Sobe a cada transição local do "estou indo". Um polling que COMEÇOU antes
  /// dela traz uma leitura anterior ao ack: aplicá-la faria a faixa voltar a
  /// "pediu ajuda" com o botão de novo, depois de o servidor já ter confirmado.
  int _ackEpoch = 0;

  /// Sinais desde o início de ontem (hora local): cobre "hoje" para o status de
  /// dose e dá folga à linha do tempo, sem os N últimos misturarem leituras do
  /// relógio e empurrarem a dose do dia para fora da página.
  DateTime _signalsSince() {
    final n = _now();
    return DateTime(n.year, n.month, n.day - 1);
  }

  /// Linha do tempo e confirmações de dose, em duas chamadas. As duas precisam
  /// vir para o dia ser afirmável: se uma falha, o painel diz que não carregou.
  Future<bool> _fetchSignals(String homeId) async {
    final since = _signalsSince();
    final timeline = await _getCareSignalsUseCase(homeId, since: since);
    final adherence = await _getCareSignalsUseCase(
      homeId,
      since: DateTime(_now().year, _now().month, _now().day),
      type: 'adherence',
    );
    final ok = timeline is Success<List<CareSignal>> &&
        adherence is Success<List<CareSignal>>;
    if (ok) {
      _signals = timeline.data;
      _adherence = adherence.data;
    }
    return ok;
  }

  Future<void> _onLoad(
    LoadDashboardEvent event,
    Emitter<DashboardState> emit,
  ) async {
    final homeId = _session.homeId;
    if (homeId == null) {
      emit(const DashboardState.error('Nenhuma casa cadastrada.'));
      return;
    }
    // Recarregar com o painel já na tela NÃO o troca por "carregando"/"erro" em tela cheia: o SOS
    // em aberto e o botão "estou indo" são a única coisa que não espera.
    final refreshing = state.status == DashboardStatus.ready;
    if (!refreshing) emit(const DashboardState.loading());

    final homeResult = await _getHomeUseCase(homeId);
    if (homeResult is Failure<HomeDetail>) {
      if (refreshing) {
        // Mantém o conteúdo e diz, no próprio painel, que o que se vê pode estar velho.
        emit(state.copyWith(staleSince: state.staleSince ?? _now(), asOf: _now()));
        return;
      }
      emit(DashboardState.error(AppFailureMessage.resolve(homeResult.failure)));
      return;
    }
    final homeDetail = (homeResult as Success<HomeDetail>).data;

    // O risco é "o que der" (uma casa nova pode não ter nenhum), mas a falha é
    // DITA: sem a flag, "sem leituras" e "não consegui carregar" seriam iguais.
    Score? topScore;
    final scoresResult = await _getScoresUseCase(homeId);
    final scoresOk = scoresResult is Success<List<Score>>;
    if (scoresOk) topScore = _highestRisk(scoresResult.data);

    final medsResult = await _getMedicationsUseCase(homeId);
    final medsOk = medsResult is Success<List<Medication>>;
    _medications = medsOk ? medsResult.data : const [];
    final signalsOk = await _fetchSignals(homeId);
    if (!signalsOk) {
      _signals = const [];
      _adherence = const [];
    }
    final emergencyResult = await _getActiveEmergencyUseCase(homeId);
    final emergencyOk = emergencyResult is Success<ActiveEmergency?>;
    final emergency = emergencyOk ? emergencyResult.data : null;

    _pollFailures = 0;
    _resolvedAt = null;
    emit(DashboardState(
      status: DashboardStatus.ready,
      homeDetail: homeDetail,
      topScore: topScore,
      userFirstName: _session.userFirstName,
      medicationsToday:
          CareTodayBuilder.medicationsToday(_medications, _adherence, _now()),
      timeline: _timeline(homeDetail),
      activeEmergency: emergency,
      // Falha NÃO é lista vazia: cada bloco diz se carregou.
      scoresLoaded: scoresOk,
      medicationsLoaded: medsOk,
      signalsLoaded: signalsOk,
      emergencyKnown: emergencyOk,
      asOf: _now(),
      lastSyncAt: _now(),
    ));

    _startPolling();
  }

  Future<void> _onPolled(
    DashboardPolledEvent event,
    Emitter<DashboardState> emit,
  ) async {
    final homeId = _session.homeId;
    if (homeId == null || state.status != DashboardStatus.ready || _polling) {
      return;
    }
    _polling = true;
    try {
      final epoch = _ackEpoch;
      final emergencyResult = await _getActiveEmergencyUseCase(homeId);
      final signalsOkRead = await _fetchSignals(homeId);
      // Se o risco não carregou, o polling também tenta de novo.
      final scoresResult =
          state.scoresLoaded ? null : await _getScoresUseCase(homeId);
      // Se os remédios não carregaram na abertura, o polling tenta de novo.
      final medsResult =
          state.medicationsLoaded ? null : await _getMedicationsUseCase(homeId);
      final emergencyOk = emergencyResult is Success<ActiveEmergency?>;
      final decision = emergencyOk
          ? await _decideEmergency(emergencyResult.data)
          : const _EmergencyDecision();
      if (isClosed) return;

      // A partir daqui NÃO há mais `await`: tudo se aplica ao estado mais novo
      // (inclusive o `acknowledging` que o toque em "estou indo" acabou de ligar).
      final signalsOk = signalsOkRead;
      final ackRaced = epoch != _ackEpoch || state.acknowledging;

      var next = state.copyWith(asOf: _now());
      if (medsResult is Success<List<Medication>>) {
        _medications = medsResult.data;
        next = next.copyWith(medicationsLoaded: true);
      }
      if (scoresResult is Success<List<Score>>) {
        next = next.copyWith(
          scoresLoaded: true,
          topScore: _highestRisk(scoresResult.data),
        );
      }
      if (signalsOk) next = next.copyWith(signalsLoaded: true);
      if (signalsOk || medsResult is Success<List<Medication>>) {
        next = next.copyWith(
          medicationsToday:
              CareTodayBuilder.medicationsToday(_medications, _adherence, _now()),
          timeline: _timeline(state.homeDetail),
        );
      }

      if (!emergencyOk) {
        // Não sei se há SOS: a tela diz que não conseguiu verificar.
        next = next.copyWith(emergencyKnown: false);
      } else if (!ackRaced) {
        next = next.copyWith(emergencyKnown: true);
        if (decision.clear) {
          next = next.copyWith(clearEmergency: true, acknowledgeFailed: false);
        } else if (decision.set != null) {
          // Um desfecho novo encerra a falha de uma confirmação antiga: as duas frases
          // ("alguém está indo" e "não consegui confirmar") não podem coexistir.
          next = next.copyWith(
            activeEmergency: decision.set,
            acknowledgeFailed: decision.set!.isOpen ? null : false,
          );
        }
        if (decision.restartLinger) _resolvedAt = _now();
        if (decision.stopLinger) _resolvedAt = null;
      }
      // (Corrida com o ack: a leitura é anterior à confirmação; o próximo
      // polling já vê o servidor depois dela.)

      // Falha de rede não derruba a tela: a última leitura fica — mas depois de
      // algumas falhas seguidas a tela diz que o que mostra pode estar velho.
      if (!emergencyOk || !signalsOk) {
        _pollFailures++;
        if (_pollFailures >= _staleAfterFailures && next.staleSince == null) {
          next = next.copyWith(staleSince: _now());
        }
      } else if (!ackRaced) {
        // Só uma leitura COMPLETA e aplicada conta como sincronizada: se a de SOS foi descartada
        // por causa do ack, "última atualização" não pode citar esse instante.
        _pollFailures = 0;
        next = next.copyWith(clearStale: true, lastSyncAt: _now());
      }
      emit(next);
    } finally {
      _polling = false;
    }
  }

  /// Decide o que fazer com a faixa de SOS, dado o que o servidor diz estar em
  /// aberto. Pode consultar o desfecho (rede), então não toca no estado.
  Future<_EmergencyDecision> _decideEmergency(ActiveEmergency? open) async {
    if (open != null) {
      return _EmergencyDecision(set: open, stopLinger: true);
    }

    final current = state.activeEmergency;
    if (current == null) return const _EmergencyDecision();

    if (current.isOpen) {
      // Estava em aberto e deixou de estar: outra pessoa confirmou, ou a Maria
      // cancelou. Sumir calada seria pior que não ter mostrado — pergunta ao
      // servidor como terminou.
      return _lookupOutcome(current, restartLinger: true);
    }

    // Já é um desfecho: fica por um instante e depois some.
    final resolved = _resolvedAt;
    if (resolved != null && _now().difference(resolved) >= _finalLinger) {
      return const _EmergencyDecision(clear: true, stopLinger: true);
    }
    // "Encerrado" é o desfecho de quem não conseguiu saber como terminou: tenta
    // de novo enquanto está na tela (a rede pode ter voltado).
    if (current.state == 'closed') return _lookupOutcome(current);
    return const _EmergencyDecision();
  }

  Future<_EmergencyDecision> _lookupOutcome(
    ActiveEmergency current, {
    bool restartLinger = false,
  }) async {
    final outcome = await _getEmergencyOutcomeUseCase(current.id);
    if (outcome is Success<ActiveEmergency> && !outcome.data.isOpen) {
      return _EmergencyDecision(
        set: outcome.data.withCreatedAtFrom(current),
        restartLinger: restartLinger,
      );
    }
    if (current.state == 'closed') return const _EmergencyDecision();
    // Não deu para saber como terminou: diz só que deixou de estar em aberto.
    return _EmergencyDecision(
      set: ActiveEmergency(
        id: current.id,
        state: 'closed',
        createdAt: current.createdAt,
      ),
      restartLinger: restartLinger,
    );
  }

  Future<void> _onAcknowledge(
    AcknowledgeEmergencyEvent event,
    Emitter<DashboardState> emit,
  ) async {
    if (state.acknowledging) return;
    _ackEpoch++;
    emit(state.copyWith(acknowledging: true, acknowledgeFailed: false));

    final result = await _acknowledgeEmergencyUseCase(event.emergencyId);
    switch (result) {
      case Success<ActiveEmergency>(:final data):
        _resolvedAt = _now();
        // O AckResponse não traz o horário do pedido: mantém o que já se sabia.
        emit(state.copyWith(
          activeEmergency: data.withCreatedAtFrom(state.activeEmergency),
          acknowledging: false,
        ));
      case Failure<ActiveEmergency>():
        // Sem sucesso falso: o alerta continua na tela e a falha é dita.
        emit(state.copyWith(acknowledging: false, acknowledgeFailed: true));
    }
    _ackEpoch++;
  }

  List<CareActivity> _timeline(HomeDetail? detail) {
    final full = detail?.patientName ?? detail?.home.label ?? '';
    final first = full.trim().split(RegExp(r'\s+')).first;
    return CareTodayBuilder.timeline(
      _signals,
      _medications,
      patientFirstName: first.isEmpty ? 'A paciente' : first,
    );
  }

  void _startPolling() {
    _pollTimer?.cancel();
    if (pollInterval == Duration.zero) return;
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (!isClosed) add(const DashboardPolledEvent());
    });
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }

  Score? _highestRisk(List<Score> scores) {
    if (scores.isEmpty) return null;
    // Ordena uma cópia: a lista vem do repositório e não é nossa para mexer.
    final ranked = [...scores]..sort((a, b) => b.score.compareTo(a.score));
    return ranked.first;
  }
}
