import 'package:aura/core/errors/result.dart';
import 'package:aura/core/network/error_mapper.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import '../../domain/entities/home.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_datasource.dart';

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this._remoteDataSource, this._tokenStore, this._session);

  final HomeRemoteDataSource _remoteDataSource;
  final TokenStore _tokenStore;
  final AuthSession _session;

  @override
  Future<Result<Home>> createHome({
    required String patientName,
    String? birthDate,
    required String cep,
    String? label,
  }) async {
    try {
      final data = await _remoteDataSource.createHome(
        patientName: patientName,
        birthDate: birthDate,
        cep: cep,
        label: label,
      );
      final home = Home(
        id: data['homeId'] as String,
        label: label ?? 'Casa',
        address: (data['address'] as String?) ?? '',
        lat: (data['lat'] as num?)?.toDouble(),
        lng: (data['lng'] as num?)?.toDouble(),
      );
      await _tokenStore.saveHomeId(home.id);
      _session.setHomeId(home.id);
      return Success(home);
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<HomeDetail>> getHome(String homeId) async {
    try {
      final data = await _remoteDataSource.getHome(homeId);
      // `GET /homes/{id}` devolve a casa num objeto plano (HomeResponse do
      // backend-spring), com o paciente e o checklist no mesmo nível.
      final checklist = (data['safetyChecklist'] as Map?)?.map(
            (k, v) => MapEntry(k as String, v as bool),
          ) ??
          <String, bool>{};
      return Success(
        HomeDetail(
          home: Home(
            id: data['id'] as String,
            label: (data['label'] as String?) ?? 'Casa',
            address: (data['address'] as String?) ?? '',
            lat: (data['lat'] as num?)?.toDouble(),
            lng: (data['lng'] as num?)?.toDouble(),
          ),
          patientName: data['patientName'] as String?,
          checklist: checklist,
        ),
      );
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<Map<String, bool>>> updateChecklist(
    String homeId,
    Map<String, bool> items,
  ) async {
    try {
      final data = await _remoteDataSource.updateChecklist(homeId, items);
      final checklist = (data['safetyChecklist'] as Map?)?.map(
            (k, v) => MapEntry(k as String, v as bool),
          ) ??
          <String, bool>{};
      return Success(checklist);
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }
}
