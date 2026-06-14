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
}
