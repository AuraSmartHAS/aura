import 'package:aura/core/errors/result.dart';
import 'package:aura/core/network/error_mapper.dart';

import '../../domain/entities/care_signal.dart';
import '../../domain/repositories/care_feed_repository.dart';
import '../datasources/care_feed_remote_datasource.dart';

class CareFeedRepositoryImpl implements CareFeedRepository {
  CareFeedRepositoryImpl(this._remote);

  final CareFeedRemoteDataSource _remote;

  @override
  Future<Result<List<CareSignal>>> getSignals(String homeId,
      {int limit = 200, DateTime? since, String? type}) async {
    try {
      final data = await _remote.getSignals(homeId,
          limit: limit, since: since, type: type);
      return Success([
        for (final raw in data) _signal(raw as Map<String, dynamic>),
      ]);
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<ActiveEmergency?>> getActiveEmergency(String homeId) async {
    try {
      final data = await _remote.getActiveEmergency(homeId);
      return Success(data == null ? null : _emergency(data));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<ActiveEmergency>> getEmergencyOutcome(
      String emergencyId) async {
    try {
      return Success(_emergency(await _remote.getEmergency(emergencyId)));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<ActiveEmergency>> acknowledge(String emergencyId) async {
    try {
      final data = await _remote.acknowledge(emergencyId);
      return Success(_emergency(data));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  static CareSignal _signal(Map<String, dynamic> json) => CareSignal(
        id: json['id'] as String,
        type: (json['type'] as String?) ?? '',
        source: (json['source'] as String?) ?? '',
        value: Map<String, dynamic>.from((json['value'] as Map?) ?? const {}),
        capturedAt: DateTime.parse(json['capturedAt'] as String),
      );

  /// Serve tanto ao `StatusResponse` do GET quanto ao `AckResponse` do ack:
  /// os dois trazem o id e o estado, e o resto é opcional.
  static ActiveEmergency _emergency(Map<String, dynamic> json) =>
      ActiveEmergency(
        id: (json['emergencyId'] as String?) ?? (json['id'] as String? ?? ''),
        state: (json['state'] as String?) ?? '',
        createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
            DateTime.now(),
        acknowledgedByName: json['acknowledgedByName'] as String?,
        spokenMessage: json['spokenMessage'] as String?,
      );
}
