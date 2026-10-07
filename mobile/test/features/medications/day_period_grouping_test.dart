import 'package:aura/features/medications/domain/day_period_grouping.dart';
import 'package:aura/features/medications/domain/entities/medication.dart';
import 'package:flutter_test/flutter_test.dart';

Medication _med(String name, List<String> times) =>
    Medication(id: name, homeId: 'home-1', name: name, times: times);

/// Resumo legível: período -> ["Nome 08:00,09:00", ...].
Map<MedicationPeriod, List<String>> _summary(List<Medication> meds) => {
      for (final g in groupByDayPeriod(meds))
        g.period: [
          for (final e in g.entries)
            '${e.medication.name}${e.times.isEmpty ? '' : ' ${e.times.join(',')}'}',
        ],
    };

void main() {
  group('periodOf (bordas)', () {
    test('Manhã de 05:00 a 11:59', () {
      expect(periodOf('05:00'), MedicationPeriod.morning);
      expect(periodOf('08:00'), MedicationPeriod.morning);
      expect(periodOf('11:59'), MedicationPeriod.morning);
    });

    test('Tarde de 12:00 a 17:59', () {
      expect(periodOf('12:00'), MedicationPeriod.afternoon);
      expect(periodOf('17:59'), MedicationPeriod.afternoon);
    });

    test('Noite de 18:00 a 04:59, atravessando a meia-noite', () {
      expect(periodOf('18:00'), MedicationPeriod.evening);
      expect(periodOf('23:59'), MedicationPeriod.evening);
      expect(periodOf('00:00'), MedicationPeriod.evening);
      expect(periodOf('04:59'), MedicationPeriod.evening);
    });

    test('texto legado ou horário inválido não é período', () {
      for (final raw in ['8h', 'manhã', '', '24:00', '12:60', 'abc']) {
        expect(periodOf(raw), isNull, reason: raw);
      }
    });
  });

  group('groupByDayPeriod', () {
    test('08:00 vai para Manhã, não para "Sem horário definido"', () {
      expect(
          _summary([
            _med('Losartana', ['08:00'])
          ]),
          {
            MedicationPeriod.morning: ['Losartana 08:00'],
          });
    });

    test('grupos na ordem do dia e medicamentos por horário', () {
      final result = _summary([
        _med('Sem hora', []),
        _med('Noturno', ['22:00']),
        _med('Tarde', ['14:00']),
        _med('Cedo', ['05:00']),
        _med('Madrugada', ['00:30']),
        _med('Antes do almoço', ['11:59']),
      ]);

      expect(result.keys.toList(), [
        MedicationPeriod.morning,
        MedicationPeriod.afternoon,
        MedicationPeriod.evening,
        MedicationPeriod.unscheduled,
      ]);
      expect(result[MedicationPeriod.morning],
          ['Cedo 05:00', 'Antes do almoço 11:59']);
      // 00:30 ainda é "Noite" e vem depois das 22:00.
      expect(result[MedicationPeriod.evening],
          ['Noturno 22:00', 'Madrugada 00:30']);
      expect(result[MedicationPeriod.unscheduled], ['Sem hora']);
    });

    test('horários em períodos diferentes aparecem em cada período', () {
      final result = _summary([
        _med('Metformina', ['20:00', '08:00', '13:00', '07:00']),
      ]);

      expect(result, {
        MedicationPeriod.morning: ['Metformina 07:00,08:00'],
        MedicationPeriod.afternoon: ['Metformina 13:00'],
        MedicationPeriod.evening: ['Metformina 20:00'],
      });
    });

    test('bordas 17:59/18:00 e 04:59/05:00 separam os períodos', () {
      final result = _summary([
        _med('A', ['17:59', '18:00']),
        _med('B', ['04:59', '05:00']),
      ]);

      expect(result[MedicationPeriod.morning], ['B 05:00']);
      expect(result[MedicationPeriod.afternoon], ['A 17:59']);
      expect(result[MedicationPeriod.evening], ['A 18:00', 'B 04:59']);
    });

    test('texto legado cai em "Sem horário definido" sem quebrar', () {
      final result = _summary([
        _med('Legado', ['8h', 'manhã']),
        _med('Misto', ['8h', '09:00']),
      ]);

      expect(result, {
        MedicationPeriod.morning: ['Misto 09:00'],
        MedicationPeriod.unscheduled: ['Legado'],
      });
    });

    test('lista vazia não gera grupos', () {
      expect(groupByDayPeriod(const []), isEmpty);
    });
  });
}
