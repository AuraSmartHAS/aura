import 'package:aura/core/errors/result.dart';
import 'package:aura/core/network/error_mapper.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import '../../domain/repositories/consent_repository.dart';
import '../datasources/consent_remote_datasource.dart';

class ConsentRepositoryImpl implements ConsentRepository {
  ConsentRepositoryImpl(this._remoteDataSource, this._tokenStore, this._session);

  final ConsentRemoteDataSource _remoteDataSource;
  final TokenStore _tokenStore;
  final AuthSession _session;

  /// Current policy version (mirrors the backend default).
  static const currentVersion = '2026-06';

  @override
  Future<Result<void>> accept({String version = currentVersion}) async {
    try {
      await _remoteDataSource.accept(version);
      await _tokenStore.setConsentAccepted();
      _session.onConsentAccepted();
      return const Success(null);
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }
}
