/// Horas na língua da família, compartilhadas pelas telas do familiar.
library;

/// "14:32" hoje; "ontem 14:32"; "05/10 14:32" antes disso.
String careClock(DateTime at, DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final hhmm = '${two(at.hour)}:${two(at.minute)}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  // Arredonda (não trunca): num dia de 23 h ou 25 h, "ontem" continua sendo ontem.
  final diff = (today.difference(day).inHours / 24).round();
  if (diff == 0) return hhmm;
  if (diff == 1) return 'ontem $hhmm';
  return '${two(at.day)}/${two(at.month)} $hhmm';
}

/// "agora", "há 5 min", "há 2 h", "ontem 14:32"…
String careAgo(DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 6) return 'há ${diff.inHours} h';
  return careClock(at, now);
}
