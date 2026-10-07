/// Groups the home's medications by period of the day from their `HH:mm`
/// times (the format the server stores and returns).
///
/// Convention (inclusive bounds, 24h clock):
/// - Manhã: 05:00–11:59
/// - Tarde: 12:00–17:59
/// - Noite: 18:00–04:59 (crosses midnight; 00:00–04:59 sorts after 23:59)
///
/// A medication with times in several periods shows up in each of them, with
/// only that period's times. Only a medication without any readable time goes
/// to "Sem horário definido"; legacy free text ("8h", "manhã") is not a time
/// and never breaks the list.
library;

import 'entities/medication.dart';

/// Periods in the order the day is read on screen.
enum MedicationPeriod { morning, afternoon, evening, unscheduled }

final _hhmm = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$');

/// Minutes since midnight for a `HH:mm` time (seconds tolerated), or null
/// when [time] is not a valid 24h time.
int? minutesOfDay(String time) {
  final match = _hhmm.firstMatch(time.trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

/// Period of a `HH:mm` time, or null when it is not a valid time.
MedicationPeriod? periodOf(String time) {
  final minutes = minutesOfDay(time);
  if (minutes == null) return null;
  if (minutes < 5 * 60 || minutes >= 18 * 60) return MedicationPeriod.evening;
  if (minutes < 12 * 60) return MedicationPeriod.morning;
  return MedicationPeriod.afternoon;
}

/// Sort key that follows the day from 05:00, so 00:30 (still "Noite")
/// comes after 23:00.
int _dayOrder(int minutes) => minutes < 5 * 60 ? minutes + 24 * 60 : minutes;

/// One medication inside a period, with only the times of that period
/// (sorted, `HH:mm`). Empty for [MedicationPeriod.unscheduled].
class PeriodEntry {
  const PeriodEntry(this.medication, this.times);

  final Medication medication;
  final List<String> times;
}

class PeriodGroup {
  const PeriodGroup(this.period, this.entries);

  final MedicationPeriod period;
  final List<PeriodEntry> entries;
}

/// Non-empty groups in day order; inside each, medications by their earliest
/// time in that period (then by name).
List<PeriodGroup> groupByDayPeriod(List<Medication> medications) {
  final buckets = <MedicationPeriod, List<(int, PeriodEntry)>>{};
  for (final med in medications) {
    final byPeriod = <MedicationPeriod, List<(int, String)>>{};
    for (final raw in med.times) {
      final minutes = minutesOfDay(raw);
      if (minutes == null) continue;
      final normalized = '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
          '${(minutes % 60).toString().padLeft(2, '0')}';
      byPeriod
          .putIfAbsent(periodOf(normalized)!, () => [])
          .add((_dayOrder(minutes), normalized));
    }
    if (byPeriod.isEmpty) {
      buckets
          .putIfAbsent(MedicationPeriod.unscheduled, () => [])
          .add((1 << 30, PeriodEntry(med, const [])));
      continue;
    }
    byPeriod.forEach((period, times) {
      times.sort((a, b) => a.$1.compareTo(b.$1));
      final unique = <String>[];
      for (final t in times) {
        if (!unique.contains(t.$2)) unique.add(t.$2);
      }
      buckets
          .putIfAbsent(period, () => [])
          .add((times.first.$1, PeriodEntry(med, unique)));
    });
  }

  return [
    for (final period in MedicationPeriod.values)
      if (buckets[period] case final items?)
        PeriodGroup(
          period,
          (items
                ..sort((a, b) {
                  final byTime = a.$1.compareTo(b.$1);
                  return byTime != 0
                      ? byTime
                      : a.$2.medication.name
                          .toLowerCase()
                          .compareTo(b.$2.medication.name.toLowerCase());
                }))
              .map((item) => item.$2)
              .toList(),
        ),
  ];
}
