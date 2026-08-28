import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:aura/core/errors/result.dart';
import 'package:aura/core/platform/phone_dialer.dart';
import 'package:aura/features/home/presentation/home_error_copy.dart';

import '../../domain/entities/emergency.dart';
import '../../domain/usecases/cancel_emergency_usecase.dart';
import '../../domain/usecases/get_emergency_status_usecase.dart';
import '../../domain/usecases/trigger_emergency_usecase.dart';
import '../sos_copy.dart';

part 'sos_event.dart';
part 'sos_state.dart';

/// Fluxo de socorro da Maria (correção C3).
///
/// As duas coisas que este bloc **não** faz, e que são o motivo de ele existir
/// deste jeito:
///
/// - **não dispara o aviso.** O toque registra a emergência no servidor e o
///   servidor dispara em `dispatchAt`. Cronômetro de cliente morre quando o
///   telefone cai da mão, a tela apaga ou o app vai a segundo plano —
///   exatamente o que acontece com quem caiu. A contagem daqui é feedback
///   visual e nada mais (regra 2);
/// - **não decide se pode prometer o aviso.** Quem decide é o servidor, em
///   `canPromiseAlert`, e a frase que a tela diz vem pronta em `spokenMessage`
///   (regra 1). Quando a promessa não pode ser feita, este bloc não inventa uma
///   redação mais otimista: ele cai para a ligação.
class SosBloc extends Bloc<SosEvent, SosState> {
  SosBloc({
    required TriggerEmergencyUseCase triggerEmergencyUseCase,
    required CancelEmergencyUseCase cancelEmergencyUseCase,
    required GetEmergencyStatusUseCase getEmergencyStatusUseCase,
    required PhoneDialer phoneDialer,
    required String emergencyPhone,
    String contactPhone = '',
    this.pollInterval = const Duration(seconds: 2),
    this.tickInterval = const Duration(seconds: 1),
  })  : _triggerEmergencyUseCase = triggerEmergencyUseCase,
        _cancelEmergencyUseCase = cancelEmergencyUseCase,
        _getEmergencyStatusUseCase = getEmergencyStatusUseCase,
        _phoneDialer = phoneDialer,
        _emergencyPhone = emergencyPhone,
        _contactPhone = contactPhone,
        super(SosState(
          contactPhoneKnown: contactPhone.trim().isNotEmpty,
          emergencyPhone: emergencyPhone,
        )) {
    on<SosRequested>(_onRequested);
    on<SosCountdownTicked>(_onCountdownTicked);
    on<SosStatusPolled>(_onStatusPolled);
    on<SosCancelRequested>(_onCancelRequested);
    on<SosCallRequested>(_onCallRequested);
  }

  final TriggerEmergencyUseCase _triggerEmergencyUseCase;
  final CancelEmergencyUseCase _cancelEmergencyUseCase;
  final GetEmergencyStatusUseCase _getEmergencyStatusUseCase;
  final PhoneDialer _phoneDialer;
  final String _emergencyPhone;
  final String _contactPhone;

  /// De quanto em quanto tempo se pergunta o estado ao servidor. Injetável para
  /// o teste não esperar em tempo real.
  final Duration pollInterval;

  /// Passo da contagem visual.
  final Duration tickInterval;

  /// Teto do acompanhamento: cerca de três minutos. Depois disso, quem estiver
  /// olhando a tela já sabe o que precisava saber, e o aparelho para de falar
  /// com o servidor.
  static const int _maxPolls = 90;

  Timer? _countdownTimer;
  Timer? _pollTimer;
  int _pollCount = 0;

  /// Pedido em voo. Segundo toque durante a chamada não abre uma segunda
  /// emergência — o servidor deduplica, mas a tela não deve nem tentar.
  bool _registering = false;

  // ── Pedido ───────────────────────────────────────────────────────

  Future<void> _onRequested(SosRequested event, Emitter<SosState> emit) async {
    if (_registering || state.isBusy) return;
    _registering = true;

    emit(state.copyWith(
      phase: SosPhase.registering,
      spokenMessage: SosCopy.sending(state.contactName),
      clearError: true,
    ));

    try {
      final result = await _triggerEmergencyUseCase(channel: event.channel);
      if (emit.isDone) return;

      switch (result) {
        case Success<EmergencyTicket>(:final data):
          _applyTicket(data, emit);
        case Failure<EmergencyTicket>(:final failure):
          // O pedido não chegou ao servidor. Nada foi avisado, e a tela não
          // pode sugerir o contrário: sobra a ligação.
          final line = failure is DeviceNotPairedFailure
              ? SosCopy.noPairedHome
              : HomeErrorCopy.forSos(failure);
          emit(state.copyWith(
            phase: SosPhase.failed,
            errorMessage: line,
            spokenMessage: line,
            canPromiseAlert: false,
            clearDegradedReason: true,
          ));
      }
    } finally {
      _registering = false;
    }
  }

  void _applyTicket(EmergencyTicket ticket, Emitter<SosState> emit) {
    final phase = _phaseFor(ticket.state, ticket.canPromiseAlert);

    emit(state.copyWith(
      phase: phase,
      emergencyId: ticket.id,
      contactName: ticket.primaryContactName,
      canPromiseAlert: ticket.canPromiseAlert,
      degradedReason: ticket.degradedReason,
      clearDegradedReason: ticket.degradedReason == null,
      cancelWindowSeconds: ticket.cancelWindowSeconds,
      secondsRemaining:
          phase == SosPhase.counting ? ticket.cancelWindowSeconds : 0,
      deduplicated: ticket.deduplicated,
      spokenMessage: _line(
        phase,
        serverLine: ticket.spokenMessage,
        contactName: ticket.primaryContactName,
      ),
      clearError: true,
    ));

    if (phase == SosPhase.counting) _startCountdown();
    _startPolling();
  }

  // ── Contagem visual ──────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(tickInterval, (_) {
      if (isClosed) return;
      add(const SosCountdownTicked());
    });
  }

  Future<void> _onCountdownTicked(
    SosCountdownTicked event,
    Emitter<SosState> emit,
  ) async {
    final remaining = state.secondsRemaining - 1;
    if (remaining <= 0) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
    }
    // Chegar a zero **não** muda a fase: quem diz que o aviso saiu é o
    // servidor, pelo acompanhamento — nunca este relógio.
    emit(state.copyWith(secondsRemaining: remaining < 0 ? 0 : remaining));
  }

  // ── Acompanhamento (polling) ─────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollCount = 0;
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (isClosed) return;
      add(const SosStatusPolled());
    });
  }

  Future<void> _onStatusPolled(
    SosStatusPolled event,
    Emitter<SosState> emit,
  ) async {
    final emergencyId = state.emergencyId;
    if (emergencyId == null) {
      _stopPolling();
      return;
    }

    if (++_pollCount > _maxPolls) {
      _stopPolling();
      return;
    }

    final result = await _getEmergencyStatusUseCase(emergencyId);
    if (emit.isDone) return;

    // Um acompanhamento que falha não desmente o que já se sabe: a tela
    // continua mostrando o último estado confirmado pelo servidor.
    if (result is! Success<EmergencyStatus>) return;

    final status = result.data;
    final phase = _phaseFor(status.state, status.canPromiseAlert);

    emit(state.copyWith(
      phase: phase,
      contactName: status.acknowledgedByName ?? state.contactName,
      canPromiseAlert: status.canPromiseAlert,
      degradedReason: status.degradedReason,
      clearDegradedReason: status.degradedReason == null,
      dispatchedAt: status.dispatchedAt,
      spokenMessage: _line(
        phase,
        serverLine: status.spokenMessage,
        contactName: status.acknowledgedByName ?? state.contactName,
        at: status.dispatchedAt,
      ),
    ));

    if (!_keepPolling(status.state)) _stopPolling();
  }

  /// Depois de confirmado, cancelado ou contido, não há mais o que perguntar.
  bool _keepPolling(EmergencyState serverState) {
    switch (serverState) {
      case EmergencyState.waitingCancel:
      case EmergencyState.dispatched:
      case EmergencyState.escalated:
        return true;
      case EmergencyState.acknowledged:
      case EmergencyState.cancelled:
      case EmergencyState.throttled:
      case EmergencyState.unknown:
        return false;
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ── "Foi engano" ─────────────────────────────────────────────────

  Future<void> _onCancelRequested(
    SosCancelRequested event,
    Emitter<SosState> emit,
  ) async {
    final emergencyId = state.emergencyId;
    if (emergencyId == null || state.isCancelling) return;

    emit(state.copyWith(isCancelling: true, clearError: true));
    _countdownTimer?.cancel();
    _countdownTimer = null;

    final result = await _cancelEmergencyUseCase(emergencyId);
    if (emit.isDone) return;

    switch (result) {
      case Success<EmergencyCancellation>(:final data):
        _stopPolling();
        emit(state.copyWith(
          phase: SosPhase.cancelled,
          isCancelling: false,
          secondsRemaining: 0,
          cancelWithinWindow: data.withinWindow,
          alertSent: data.alertSent,
          retractionSent: data.retractionSent,
          spokenMessage: data.spokenMessage ??
              SosCopy.cancelled(
                withinWindow: data.withinWindow,
                alertSent: data.alertSent,
                contactName: state.contactName,
              ),
        ));
      case Failure<EmergencyCancellation>(:final failure):
        // O cancelamento não chegou: o pedido continua de pé no servidor e a
        // tela **não** pode dizer que cancelou.
        emit(state.copyWith(
          isCancelling: false,
          errorMessage: HomeErrorCopy.forSos(failure),
        ));
    }
  }

  // ── Ligações ─────────────────────────────────────────────────────

  Future<void> _onCallRequested(
    SosCallRequested event,
    Emitter<SosState> emit,
  ) async {
    final number = switch (event.target) {
      SosCallTarget.contact => _contactPhone,
      SosCallTarget.emergencyService => _emergencyPhone,
    };

    if (number.trim().isEmpty) {
      emit(state.copyWith(dialerFailed: true));
      return;
    }

    final opened = await _phoneDialer.openDialer(number);
    if (emit.isDone) return;
    emit(state.copyWith(dialerFailed: !opened));
  }

  // ── Estado do servidor → fase da tela ────────────────────────────

  /// Traduz o estado do servidor na fase da tela.
  ///
  /// O nó da regra 1 está aqui: com `canPromiseAlert` falso, nem
  /// `waiting_cancel` nem `dispatched` viram anúncio de aviso — viram
  /// [SosPhase.failed], que é a fase que oferece a ligação. Só a confirmação da
  /// cuidadora escapa disso, porque um "estou indo" é fato observado, não
  /// promessa de transporte.
  SosPhase _phaseFor(EmergencyState serverState, bool canPromiseAlert) {
    switch (serverState) {
      case EmergencyState.waitingCancel:
        return canPromiseAlert ? SosPhase.counting : SosPhase.failed;
      case EmergencyState.dispatched:
      case EmergencyState.escalated:
        return canPromiseAlert ? SosPhase.delivered : SosPhase.failed;
      case EmergencyState.acknowledged:
        return SosPhase.acknowledged;
      case EmergencyState.cancelled:
        return SosPhase.cancelled;
      case EmergencyState.throttled:
      case EmergencyState.unknown:
        return SosPhase.failed;
    }
  }

  /// A frase da fase. **A do servidor ganha sempre**; a local só entra quando o
  /// campo vem vazio, e nunca promete mais do que ele prometeria.
  String _line(
    SosPhase phase, {
    String? serverLine,
    String? contactName,
    DateTime? at,
  }) {
    if (serverLine != null && serverLine.trim().isNotEmpty) {
      return serverLine.trim();
    }
    switch (phase) {
      case SosPhase.idle:
      case SosPhase.registering:
      case SosPhase.counting:
        return SosCopy.sending(contactName);
      case SosPhase.delivered:
        return SosCopy.delivered(contactName, at);
      case SosPhase.acknowledged:
        return SosCopy.acknowledged(contactName);
      case SosPhase.cancelled:
        return SosCopy.cancelled(
          withinWindow: state.cancelWithinWindow,
          alertSent: state.alertSent,
          contactName: contactName,
        );
      case SosPhase.failed:
        return SosCopy.failed(contactName);
    }
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    return super.close();
  }
}
