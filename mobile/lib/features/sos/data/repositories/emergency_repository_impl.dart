import 'package:aura/core/errors/result.dart';
import 'package:aura/core/network/error_mapper.dart';

import '../../domain/entities/emergency.dart';
import '../../domain/repositories/emergency_repository.dart';
import '../datasources/emergency_remote_datasource.dart';
import '../models/emergency_mapper.dart';

/// De onde sai o identificador da casa que este aparelho guarda.
///
/// É uma função, e não a sessão, porque o SOS tem de funcionar **com a sessão
/// expirada** (regra 3): quem monta este leitor decide a ordem de busca.
typedef PairedHomeIdReader = Future<String?> Function();

class EmergencyRepositoryImpl implements EmergencyRepository {
  EmergencyRepositoryImpl(
    this._remoteDataSource, {
    required PairedHomeIdReader pairedHomeId,
  }) : _pairedHomeId = pairedHomeId;

  final EmergencyRemoteDataSource _remoteDataSource;
  final PairedHomeIdReader _pairedHomeId;

  @override
  Future<Result<EmergencyTicket>> trigger({
    required EmergencyChannel channel,
  }) async {
    final String? homeId;
    try {
      homeId = await _pairedHomeId();
    } catch (e) {
      return Failure(mapDioError(e));
    }

    if (homeId == null || homeId.isEmpty) {
      return const Failure(DeviceNotPairedFailure());
    }

    try {
      final data = await _remoteDataSource.trigger(
        homeId: homeId,
        channel: channel.wireValue,
      );
      return Success(EmergencyMapper.ticketFromJson(data));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<EmergencyCancellation>> cancel(String emergencyId) async {
    try {
      final data = await _remoteDataSource.cancel(emergencyId);
      return Success(EmergencyMapper.cancellationFromJson(data));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<EmergencyStatus>> status(String emergencyId) async {
    try {
      final data = await _remoteDataSource.status(emergencyId);
      return Success(EmergencyMapper.statusFromJson(data));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }
}
