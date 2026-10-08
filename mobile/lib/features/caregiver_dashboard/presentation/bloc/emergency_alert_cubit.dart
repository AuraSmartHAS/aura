import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:aura/core/errors/result.dart';
import 'package:aura/features/home_setup/domain/usecases/get_home_usecase.dart';

import '../../domain/entities/care_signal.dart';
import '../../domain/usecases/care_feed_usecases.dart';

class EmergencyAlertState extends Equatable {
  const EmergencyAlertState({
    this.emergency,
    this.homeLabel,
    this.patientName,
    this.address,
    this.lat,
    this.lng,
    this.loading = true,
    this.loadFailed = false,
    this.acknowledging = false,
    this.acknowledgeFailed = false,
  });

  final ActiveEmergency? emergency;
  final String? homeLabel;
  final String? patientName;
  final String? address;
  final double? lat;
  final double? lng;
  final bool loading;
  final bool loadFailed;
  final bool acknowledging;
  final bool acknowledgeFailed;

  bool get canAcknowledge =>
      emergency != null && emergency!.isOpen && !acknowledging;

  EmergencyAlertState copyWith({
    ActiveEmergency? emergency,
    String? homeLabel,
    String? patientName,
    String? address,
    double? lat,
    double? lng,
    bool? loading,
    bool? loadFailed,
    bool? acknowledging,
    bool? acknowledgeFailed,
  }) =>
      EmergencyAlertState(
        emergency: emergency ?? this.emergency,
        homeLabel: homeLabel ?? this.homeLabel,
        patientName: patientName ?? this.patientName,
        address: address ?? this.address,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        loading: loading ?? this.loading,
        loadFailed: loadFailed ?? this.loadFailed,
        acknowledging: acknowledging ?? this.acknowledging,
        acknowledgeFailed: acknowledgeFailed ?? this.acknowledgeFailed,
      );

  @override
  List<Object?> get props => [
        emergency,
        homeLabel,
        patientName,
        address,
        lat,
        lng,
        loading,
        loadFailed,
        acknowledging,
        acknowledgeFailed,
      ];
}

/// A tela de socorro de quem cuida: estado do pedido (`GET /emergencies/{id}`,
/// rota aberta), dados da casa (autenticados) e o "Estou indo".
///
/// O endereço e as coordenadas chegam primeiro pelo push e valem enquanto a
/// casa não responde: no corredor do prédio, sem sinal, a tela ainda diz para
/// onde ir.
class EmergencyAlertCubit extends Cubit<EmergencyAlertState> {
  EmergencyAlertCubit({
    required this.emergencyId,
    required this.homeId,
    required GetEmergencyOutcomeUseCase getEmergency,
    required AcknowledgeEmergencyUseCase acknowledge,
    required GetHomeUseCase getHome,
    String? address,
    double? lat,
    double? lng,
    Duration pollEvery = const Duration(seconds: 10),
  })  : _getEmergency = getEmergency,
        _acknowledge = acknowledge,
        _getHome = getHome,
        _pollEvery = pollEvery,
        super(EmergencyAlertState(address: address, lat: lat, lng: lng));

  final String emergencyId;
  final String? homeId;
  final GetEmergencyOutcomeUseCase _getEmergency;
  final AcknowledgeEmergencyUseCase _acknowledge;
  final GetHomeUseCase _getHome;
  final Duration _pollEvery;
  Timer? _poll;

  Future<void> start() async {
    await Future.wait([refresh(), _loadHome()]);
    // enquanto o pedido está aberto, o estado muda sem a gente: a Maria pode
    // cancelar, outra pessoa pode dizer que está indo
    _poll = Timer.periodic(_pollEvery, (_) {
      if (state.emergency?.isOpen ?? true) refresh();
    });
  }

  Future<void> refresh() async {
    final result = await _getEmergency(emergencyId);
    if (isClosed) return;
    switch (result) {
      case Success(:final data):
        emit(state.copyWith(
          emergency: data.withCreatedAtFrom(state.emergency),
          loading: false,
          loadFailed: false,
        ));
      case Failure():
        emit(state.copyWith(loading: false, loadFailed: true));
    }
  }

  Future<void> _loadHome() async {
    final id = homeId;
    if (id == null) return;
    final result = await _getHome(id);
    if (isClosed) return;
    if (result case Success(:final data)) {
      emit(state.copyWith(
        homeLabel: data.home.label,
        patientName: data.patientName,
        address: data.home.address.isEmpty ? null : data.home.address,
        lat: data.home.lat,
        lng: data.home.lng,
      ));
    }
  }

  /// "Estou indo". Idempotente no servidor: dois toques não viram dois avisos.
  Future<void> acknowledge() async {
    if (!state.canAcknowledge) return;
    emit(state.copyWith(acknowledging: true, acknowledgeFailed: false));
    final result = await _acknowledge(emergencyId);
    if (isClosed) return;
    switch (result) {
      case Success(:final data):
        emit(state.copyWith(
          emergency: data.withCreatedAtFrom(state.emergency),
          acknowledging: false,
        ));
      case Failure():
        emit(state.copyWith(acknowledging: false, acknowledgeFailed: true));
        // o pedido pode ter sido cancelado no meio: o estado novo explica o erro
        await refresh();
    }
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}
