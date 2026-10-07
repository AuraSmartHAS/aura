/// Parsing/validation of the "Horário" field. The server only accepts 24h
/// `HH:mm` times (400 otherwise), so the form checks before sending.
library;

const scheduleFormatError =
    'Use horários no formato HH:mm, separados por vírgula (ex.: 08:00, 20:00).';

final _time = RegExp(r'^(\d{1,2}):(\d{2})$');
final _separators = RegExp(r'[,;]|\s+e\s+|\s+');

/// Result of [parseScheduleInput]: either [times] or an [error] message.
class ScheduleParse {
  const ScheduleParse.ok(this.times) : error = null;
  const ScheduleParse.invalid(this.error) : times = const [];

  final List<String> times;
  final String? error;

  bool get isValid => error == null;
}

/// Splits "08:00, 20:00" (comma, semicolon, space or " e ") into normalized
/// `HH:mm` times, sorted and without duplicates. "8:00" becomes "08:00".
/// Empty input is valid and means "no fixed time".
ScheduleParse parseScheduleInput(String raw) {
  final parts = raw
      .trim()
      .split(_separators)
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);
  final times = <String>{};
  for (final part in parts) {
    final match = _time.firstMatch(part);
    if (match == null) return const ScheduleParse.invalid(scheduleFormatError);
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      return const ScheduleParse.invalid(scheduleFormatError);
    }
    times.add(
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
    );
  }
  return ScheduleParse.ok(times.toList()..sort());
}
