import 'package:aura/features/medications/domain/entities/medication.dart';

import 'entities/care_signal.dart';
import 'entities/care_today.dart';

/// Eventos que o agente de voz e o app registram, na frase da família.
/// Mesmo vocabulário do painel web e do app React Native: um evento novo se
/// traduz aqui, e o que não está na lista aparece legível, nunca cru.
const Map<String, String> careEventLabels = {
  'near_fall': 'uma quase-queda',
  'fall': 'uma queda',
  'dizziness': 'tontura',
  'tremor_worse': 'tremor mais forte que o normal',
  'pain': 'dor',
  'poor_sleep': 'uma noite mal dormida',
  'night_trip': 'idas noturnas ao banheiro',
  'forgetfulness': 'esquecimento',
  'confusion': 'confusão na fala',
  'sadness': 'tristeza',
  'slippery_floor': 'piso escorregadio',
  'poor_air': 'ar de má qualidade',
};

/// Onde aconteceu, já com a preposição.
const Map<String, String> carePlaceLabels = {
  'bathroom': 'no banheiro',
  'kitchen': 'na cozinha',
  'bedroom': 'no quarto',
  'living_room': 'na sala',
  'stairs': 'na escada',
};

/// Monta o "Hoje" e a linha do tempo da família a partir de sinais, remédios e
/// a hora local. Puro: sem rede, sem relógio escondido — o que o teste afirma é
/// o que a tela mostra.
class CareTodayBuilder {
  const CareTodayBuilder._();

  /// Quanto depois do horário a dose passa a contar como atrasada. Sem folga,
  /// o painel acenderia "atrasada" no minuto exato de cada dose — alarme que
  /// ensina a família a ignorar o indicador.
  static const int graceMinutes = 30;

  /// Situação de cada remédio ativo hoje ([now] em hora local).
  ///
  /// Cada confirmação "tomei" cobre o horário **mais próximo** dela; um horário
  /// coberto por duas confirmações conta uma vez. É isto que impede a Maria,
  /// repetindo a fala ("tomei a levodopa" às 08:05 e de novo às 09:30), de fechar
  /// o dia e esconder a dose das 20:00 que ainda não foi tomada.
  static List<MedicationToday> medicationsToday(
    List<Medication> medications,
    List<CareSignal> signals,
    DateTime now,
  ) {
    final nowMinutes = now.hour * 60 + now.minute;
    final result = <MedicationToday>[];

    for (final med in medications.where((m) => m.active)) {
      final mine = signals
          .where((s) =>
              s.type == 'adherence' &&
              s.value['medicationId'] == med.id &&
              _sameDay(s.capturedAt.toLocal(), now))
          .toList()
        ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

      final taken = mine.where((s) => s.value['taken'] == true).toList();
      final declined = mine.where((s) => s.value['taken'] == false).toList();

      // Só horários legíveis: texto legado ("8h") não é horário de dose.
      final slots = <(String, int)>[
        for (final t in med.times)
          if (_minutes(t) != null) (t, _minutes(t)!),
      ]..sort((a, b) => a.$2.compareTo(b.$2));

      final covered = <int>{};
      if (slots.isNotEmpty) {
        for (final signal in taken) {
          final at = signal.capturedAt.toLocal();
          final minute = at.hour * 60 + at.minute;
          var nearest = 0;
          for (var i = 1; i < slots.length; i++) {
            if ((slots[i].$2 - minute).abs() <
                (slots[nearest].$2 - minute).abs()) {
              nearest = i;
            }
          }
          covered.add(nearest);
        }
      }

      final perDay = slots.length;
      final takenCount =
          perDay == 0 ? (taken.isEmpty ? 0 : 1) : covered.length;
      final firstUncovered = [
        for (var i = 0; i < slots.length; i++)
          if (!covered.contains(i)) i,
      ];

      final DoseStatus status;
      if (perDay == 0) {
        status = DoseStatus.asNeeded;
      } else if (firstUncovered.isEmpty) {
        status = DoseStatus.complete;
      } else if (firstUncovered
          .any((i) => slots[i].$2 + graceMinutes <= nowMinutes)) {
        status = DoseStatus.late;
      } else {
        status = DoseStatus.onTrack;
      }

      // "Não tomei" só pesa se não houve confirmação depois dele.
      final declinedToday = declined.isNotEmpty &&
          (taken.isEmpty ||
              declined.first.capturedAt.isAfter(taken.first.capturedAt));

      result.add(MedicationToday(
        medication: med,
        status: status,
        takenCount: takenCount,
        dosesPerDay: perDay,
        nextTime: firstUncovered.isEmpty ? null : slots[firstUncovered.first].$1,
        lastTakenAt: taken.isEmpty ? null : taken.first.capturedAt.toLocal(),
        lastSource: taken.isEmpty ? null : _source(taken.first),
        declinedToday: declinedToday,
      ));
    }
    return result;
  }

  /// Os eventos mais recentes, do mais novo para o mais antigo. Leituras do
  /// relógio ficam de fora: a linha do tempo é sobre o que a Maria disse e fez.
  static List<CareActivity> timeline(
    List<CareSignal> signals,
    List<Medication> medications, {
    required String patientFirstName,
    int limit = 6,
  }) {
    final meds = {for (final m in medications) m.id: m};
    final sorted = [...signals]
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

    final out = <CareActivity>[];
    for (final s in sorted) {
      final activity = _activityOf(s, meds, patientFirstName);
      if (activity != null) out.add(activity);
      if (out.length == limit) break;
    }
    return out;
  }

  static CareActivity? _activityOf(
    CareSignal s,
    Map<String, Medication> meds,
    String who,
  ) {
    if (s.source == 'wearable') return null;
    final at = s.capturedAt.toLocal();

    if (s.type == 'adherence' && s.value['medicationId'] is String) {
      final name = meds[s.value['medicationId']]?.name ?? 'um remédio';
      final taken = s.value['taken'] != false;
      return CareActivity(
        id: s.id,
        kind: ActivityKind.dose,
        title: taken
            ? '$who confirmou $name'
            : '$who disse que não tomou $name',
        source: _source(s),
        occurredAt: at,
        concerning: !taken,
      );
    }

    final event = s.value['event'];
    if (event is String) {
      if (event == 'sos') {
        return CareActivity(
          id: s.id,
          kind: ActivityKind.sos,
          title: '$who pediu ajuda (SOS)',
          source: s.value['channel'] == 'voice'
              ? ActivitySource.voice
              : ActivitySource.app,
          occurredAt: at,
          concerning: true,
        );
      }
      final label = careEventLabels[event];
      final place = s.value['place'];
      final placeText = place is String
          ? (carePlaceLabels[place] ?? 'em ${_humanize(place)}')
          : null;
      final what = label ?? _humanize(event);
      return CareActivity(
        id: s.id,
        kind: ActivityKind.symptom,
        title: '$who relatou $what${placeText == null ? '' : ' $placeText'}',
        source: _source(s),
        occurredAt: at,
        concerning: true,
      );
    }
    return null;
  }

  static ActivitySource _source(CareSignal s) => switch (s.source) {
        'voice' => ActivitySource.voice,
        'wearable' => ActivitySource.wearable,
        _ => ActivitySource.app,
      };

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int? _minutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static String _humanize(String code) => code.replaceAll('_', ' ');
}
