import 'dart:io';

import 'package:health/health.dart';

import '../../domain/entities/vitals.dart';

/// Reads lightweight vitals from the device's health store (`health` package),
/// after an explicit opt-in. No telemetry server, no IoT — it is the user's own
/// Health Connect (Android) / HealthKit (iOS) data.
abstract class WearableLocalDataSource {
  Future<Vitals> readVitals();
}

class WearableLocalDataSourceImpl implements WearableLocalDataSource {
  WearableLocalDataSourceImpl([Health? health]) : _health = health ?? Health();

  final Health _health;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_ASLEEP,
  ];

  @override
  Future<Vitals> readVitals() async {
    await _health.configure();
    await _ensureHealthConnectAvailable();

    final granted = await _health.requestAuthorization(
      _types,
      permissions: _types.map((_) => HealthDataAccess.READ).toList(),
    );
    if (!granted) throw const WearablePermissionException();

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final dayAgo = now.subtract(const Duration(hours: 24));

    final steps = await _readSteps(midnight, now);
    final restingHr = await _readLatestHeartRate(dayAgo, now);
    final sleepHours = await _readSleepHours(dayAgo, now);

    return Vitals(
      steps: steps,
      restingHeartRate: restingHr,
      sleepHours: sleepHours,
    );
  }

  /// Health Connect is a separate app on Android < 14. If it is missing or
  /// outdated, launch the Play Store install flow and signal the caller so the
  /// user can finish setup and retry. iOS (HealthKit) is always available.
  Future<void> _ensureHealthConnectAvailable() async {
    if (!Platform.isAndroid) return;

    final status = await _health.getHealthConnectSdkStatus();
    if (status == HealthConnectSdkStatus.sdkAvailable) return;

    await _health.installHealthConnect();
    throw const WearableUnavailableException();
  }

  Future<int?> _readSteps(DateTime start, DateTime end) async {
    try {
      return await _health.getTotalStepsInInterval(start, end);
    } catch (_) {
      return null;
    }
  }

  Future<double?> _readLatestHeartRate(DateTime start, DateTime end) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: const [HealthDataType.HEART_RATE],
      );
      if (points.isEmpty) return null;
      points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      return _numericValue(points.first);
    } catch (_) {
      return null;
    }
  }

  Future<double?> _readSleepHours(DateTime start, DateTime end) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: const [HealthDataType.SLEEP_ASLEEP],
      );
      if (points.isEmpty) return null;
      final totalMinutes = points.fold<double>(
        0,
        (sum, p) => sum + p.dateTo.difference(p.dateFrom).inMinutes,
      );
      return totalMinutes / 60.0;
    } catch (_) {
      return null;
    }
  }

  double? _numericValue(HealthDataPoint point) {
    final value = point.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    return null;
  }
}
