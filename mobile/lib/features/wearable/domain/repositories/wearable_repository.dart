import 'package:aura/core/errors/result.dart';
import '../entities/vitals.dart';

abstract class WearableRepository {
  /// Reads vitals from the device (opt-in) and posts them as a `vitals` signal
  /// for the active home. Returns the readings to display.
  Future<Result<Vitals>> syncVitals();
}
