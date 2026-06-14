import 'package:aura/core/errors/result.dart';

abstract class ConsentRepository {
  /// Accepts the LGPD policy (RN-001) and persists the acceptance locally.
  Future<Result<void>> accept({String version});
}
