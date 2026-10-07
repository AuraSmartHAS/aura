part of 'dashboard_bloc.dart';

enum DashboardStatus { loading, ready, error }

class DashboardState extends Equatable {
  const DashboardState({
    required this.status,
    this.homeDetail,
    this.topScore,
    this.errorMessage,
    this.userFirstName,
    this.medicationsToday = const [],
    this.timeline = const [],
    this.activeEmergency,
    this.acknowledging = false,
    this.acknowledgeFailed = false,
    this.scoresLoaded = true,
    this.medicationsLoaded = true,
    this.signalsLoaded = true,
    this.emergencyKnown = true,
    this.staleSince,
    this.asOf,
    this.lastSyncAt,
  });

  const DashboardState.loading() : this(status: DashboardStatus.loading);

  const DashboardState.error(String message)
      : this(status: DashboardStatus.error, errorMessage: message);

  final DashboardStatus status;
  final HomeDetail? homeDetail;
  final Score? topScore;
  final String? errorMessage;

  /// Primeiro nome de quem está logado, para a saudação; `null` cumprimenta
  /// sem nome.
  final String? userFirstName;

  /// Como estão os remédios de hoje.
  final List<MedicationToday> medicationsToday;

  /// O que a Maria disse e fez, do mais novo ao mais antigo.
  final List<CareActivity> timeline;

  /// SOS em aberto — ou, por um instante, o desfecho dele (confirmado, cancelado).
  final ActiveEmergency? activeEmergency;
  final bool acknowledging;
  final bool acknowledgeFailed;

  /// Cada bloco secundário diz se CARREGOU. Lista vazia por falha não é lista
  /// vazia de verdade: sem isto a tela afirmaria "Nenhum remédio" e "Tudo em
  /// ordem" só porque a chamada caiu.
  final bool scoresLoaded;
  final bool medicationsLoaded;
  final bool signalsLoaded;

  /// Sabemos se há SOS em aberto? Falso quando `/emergencies/active` falhou: aí a
  /// tela não pode sugerir que "não há" — ela diz que não conseguiu verificar.
  final bool emergencyKnown;

  /// Desde quando o polling falha seguidamente (o que se vê pode estar velho).
  final DateTime? staleSince;

  /// Hora local da última leitura, para as frases relativas ("há 5 min").
  final DateTime? asOf;

  /// Quando a última leitura COMPLETA deu certo (o que o aviso de "desatualizado"
  /// cita; `asOf` avança mesmo quando a leitura falha).
  final DateTime? lastSyncAt;

  /// Os remédios de hoje dependem dos remédios E dos sinais.
  bool get todayAvailable => medicationsLoaded && signalsLoaded;

  /// Tudo carregou e está atualizado: só então a tela pode dizer "Tudo em ordem".
  bool get dataComplete =>
      scoresLoaded && todayAvailable && emergencyKnown && staleSince == null;

  /// Primeiro nome da paciente, para as frases da linha do tempo.
  String get patientFirstName {
    final full = homeDetail?.patientName ?? homeDetail?.home.label ?? '';
    final first = full.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'A paciente' : first;
  }

  /// Momento do evento mais recente da Maria (para "última atividade").
  DateTime? get lastActivityAt =>
      timeline.isEmpty ? null : timeline.first.occurredAt;

  /// Há algo que pede olhar: SOS em aberto, dose atrasada/recusada ou risco alto.
  bool get needsAttention =>
      (activeEmergency?.isOpen ?? false) ||
      topScore?.level == SeverityLevel.high ||
      (todayAvailable &&
          medicationsToday
              .any((m) => m.status == DoseStatus.late || m.declinedToday));

  DashboardState copyWith({
    Score? topScore,
    List<MedicationToday>? medicationsToday,
    List<CareActivity>? timeline,
    ActiveEmergency? activeEmergency,
    bool clearEmergency = false,
    bool? acknowledging,
    bool? acknowledgeFailed,
    bool? scoresLoaded,
    bool? medicationsLoaded,
    bool? signalsLoaded,
    bool? emergencyKnown,
    DateTime? staleSince,
    bool clearStale = false,
    DateTime? asOf,
    DateTime? lastSyncAt,
  }) {
    return DashboardState(
      status: status,
      homeDetail: homeDetail,
      topScore: topScore ?? this.topScore,
      errorMessage: errorMessage,
      userFirstName: userFirstName,
      medicationsToday: medicationsToday ?? this.medicationsToday,
      timeline: timeline ?? this.timeline,
      activeEmergency:
          clearEmergency ? null : (activeEmergency ?? this.activeEmergency),
      acknowledging: acknowledging ?? this.acknowledging,
      acknowledgeFailed: acknowledgeFailed ?? this.acknowledgeFailed,
      scoresLoaded: scoresLoaded ?? this.scoresLoaded,
      medicationsLoaded: medicationsLoaded ?? this.medicationsLoaded,
      signalsLoaded: signalsLoaded ?? this.signalsLoaded,
      emergencyKnown: emergencyKnown ?? this.emergencyKnown,
      staleSince: clearStale ? null : (staleSince ?? this.staleSince),
      asOf: asOf ?? this.asOf,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  @override
  List<Object?> get props => [
        status,
        homeDetail?.home.id,
        topScore?.scoreId,
        errorMessage,
        userFirstName,
        medicationsToday,
        timeline,
        activeEmergency,
        acknowledging,
        acknowledgeFailed,
        scoresLoaded,
        medicationsLoaded,
        signalsLoaded,
        emergencyKnown,
        staleSince,
        asOf,
        lastSyncAt,
      ];
}
