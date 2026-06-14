import 'package:dio/dio.dart';

import '../errors/app_failure.dart';

/// Converts a [DioException] into the project's [AppFailure] type, reading the
/// aura-server single error model: `{ "error": { "code", "message", "details" } }`.
AppFailure mapDioError(Object error) {
  if (error is! DioException) {
    return AppFailure.unexpected(message: error.toString());
  }

  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.connectionError) {
    return const AppFailure.networkError(
      message: 'Sem conexão com o servidor. Tente novamente.',
    );
  }

  final data = error.response?.data;
  final body = data is Map ? data['error'] : null;
  final code = (body is Map ? body['code'] : null) as String?;
  final message =
      (body is Map ? body['message'] : null) as String? ?? 'Erro inesperado.';

  switch (code) {
    case 'CONSENT_REQUIRED':
      return AppFailure.consentRequired(message: message);
    case 'UNAUTHORIZED':
    case 'TOKEN_EXPIRED':
    case 'INVALID_CREDENTIALS':
      return AppFailure.unauthorized(message: message);
    case 'FORBIDDEN':
      return AppFailure.forbidden(message: message);
    case 'NOT_FOUND':
      return AppFailure.notFound(message: message);
    case 'CONFLICT':
      return AppFailure.conflict(message: message);
    case 'VALIDATION_ERROR':
    case 'UNKNOWN_DIMENSION':
      return AppFailure.validation(message: message);
    case 'SCORING_UNAVAILABLE':
      return AppFailure.serviceUnavailable(message: message);
    case 'APPROVAL_REQUIRED':
    case 'PRESCRIPTION_BLOCKED':
    case 'SCORE_HOME_MISMATCH':
    case 'NO_PRODUCT':
      return AppFailure.businessRule(code: code!, message: message);
    default:
      return AppFailure.unexpected(message: message);
  }
}
