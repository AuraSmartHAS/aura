import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_failure.freezed.dart';

@freezed
class AppFailure with _$AppFailure {
  const factory AppFailure.unexpected({
    required String message,
  }) = _Unexpected;

  const factory AppFailure.notFound({
    required String message,
  }) = _NotFound;

  const factory AppFailure.unauthorized({
    required String message,
  }) = _Unauthorized;

  const factory AppFailure.validation({
    required String message,
  }) = _Validation;

  const factory AppFailure.networkError({
    required String message,
  }) = _NetworkError;

  /// RN-001: LGPD consent must be accepted before health data (422 CONSENT_REQUIRED).
  const factory AppFailure.consentRequired({
    required String message,
  }) = _ConsentRequired;

  /// 409 CONFLICT (duplicate email, recommendation already approved, terminal order).
  const factory AppFailure.conflict({
    required String message,
  }) = _Conflict;

  /// 403 FORBIDDEN (RBAC/RLS).
  const factory AppFailure.forbidden({
    required String message,
  }) = _Forbidden;

  /// 422 business rule (APPROVAL_REQUIRED, PRESCRIPTION_BLOCKED, NO_PRODUCT, ...).
  const factory AppFailure.businessRule({
    required String code,
    required String message,
  }) = _BusinessRule;

  /// 503 SCORING_UNAVAILABLE (circuit breaker open).
  const factory AppFailure.serviceUnavailable({
    required String message,
  }) = _ServiceUnavailable;
}
