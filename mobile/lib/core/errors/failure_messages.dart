import 'app_failure.dart';

/// Maps an [AppFailure] to a user-facing message (PT). Presentation layer only.
extension AppFailureMessage on AppFailure {
  String get userMessage => when(
        unexpected: (m) => m,
        notFound: (m) => m,
        unauthorized: (m) => m,
        validation: (m) => m,
        networkError: (m) => m,
        consentRequired: (m) => m,
        conflict: (m) => m,
        forbidden: (m) => m,
        businessRule: (code, m) => m,
        serviceUnavailable: (m) => m,
      );

  /// Resolves a `Failure`'s payload (which is typed `dynamic` in `Result`).
  static String resolve(Object? failure) {
    if (failure is AppFailure) return failure.userMessage;
    return failure?.toString() ?? 'Erro inesperado.';
  }
}
