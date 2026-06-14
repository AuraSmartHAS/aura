import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/network/error_mapper.dart';
import 'package:aura/core/session/auth_session.dart';
import '../../domain/entities/vitals.dart';
import '../../domain/repositories/wearable_repository.dart';
import '../datasources/signals_remote_datasource.dart';
import '../datasources/wearable_local_datasource.dart';

class WearableRepositoryImpl implements WearableRepository {
  WearableRepositoryImpl(
    this._localDataSource,
    this._signalsDataSource,
    this._session,
  );

  final WearableLocalDataSource _localDataSource;
  final SignalsRemoteDataSource _signalsDataSource;
  final AuthSession _session;

  @override
  Future<Result<Vitals>> syncVitals() async {
    try {
      final vitals = await _localDataSource.readVitals();
      final homeId = _session.homeId;
      final value = vitals.toSignalValue();
      if (homeId != null && value.isNotEmpty) {
        await _signalsDataSource.postVitals(homeId, value);
      }
      return Success(vitals);
    } on WearableUnavailableException {
      return const Failure(
        AppFailure.serviceUnavailable(
          message: 'O Health Connect não está disponível neste dispositivo. '
              'Abrimos a loja para você instalá-lo — conclua a instalação e '
              'toque em conectar novamente.',
        ),
      );
    } on WearablePermissionException {
      return const Failure(
        AppFailure.unauthorized(
          message: 'Permissão de dados de saúde negada. Você pode liberar nas '
              'configurações do dispositivo.',
        ),
      );
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }
}
