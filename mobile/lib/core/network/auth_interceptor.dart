import 'package:dio/dio.dart';

import '../session/auth_session.dart';
import '../session/token_store.dart';

/// Injects the `Authorization: Bearer <token>` header and transparently
/// refreshes the access token once on `401 TOKEN_EXPIRED`, replaying the
/// original request. If refresh fails, the session is cleared.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStore tokenStore,
    required AuthSession session,
    required String baseUrl,
  })  : _tokenStore = tokenStore,
        _session = session,
        // Separate dio instance avoids re-entering this interceptor on refresh.
        _refreshDio = Dio(BaseOptions(baseUrl: baseUrl));

  final TokenStore _tokenStore;
  final AuthSession _session;
  final Dio _refreshDio;

  static const _retriedFlag = 'x-retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStore.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isTokenExpired = err.response?.statusCode == 401 &&
        _errorCode(err) == 'TOKEN_EXPIRED' &&
        err.requestOptions.extra[_retriedFlag] != true;

    if (!isTokenExpired) {
      return handler.next(err);
    }

    final refreshed = await _refresh();
    if (!refreshed) {
      await _session.onLoggedOut();
      return handler.next(err);
    }

    try {
      final newToken = await _tokenStore.accessToken;
      final options = err.requestOptions
        ..extra[_retriedFlag] = true
        ..headers['Authorization'] = 'Bearer $newToken';
      final response = await _refreshDio.fetch(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  Future<bool> _refresh() async {
    final refreshToken = await _tokenStore.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final res = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = res.data as Map<String, dynamic>;
      await _tokenStore.updateTokens(
        accessToken: data['token'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String? _errorCode(DioException err) {
    final data = err.response?.data;
    final body = data is Map ? data['error'] : null;
    return body is Map ? body['code'] as String? : null;
  }
}
