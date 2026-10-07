import 'package:aura/features/medications/domain/schedule_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aceita HH:mm separados por vírgula, espaço ou "e"', () {
    final parsed = parseScheduleInput('20:00, 08:00 e 14:00 22:00');

    expect(parsed.isValid, isTrue);
    expect(parsed.times, ['08:00', '14:00', '20:00', '22:00']);
  });

  test('normaliza 8:00 para 08:00 e remove repetidos', () {
    expect(parseScheduleInput('8:00, 08:00').times, ['08:00']);
  });

  test('campo vazio é válido e significa sem horário fixo', () {
    final parsed = parseScheduleInput('   ');

    expect(parsed.isValid, isTrue);
    expect(parsed.times, isEmpty);
  });

  test('texto livre e hora fora do relógio são recusados', () {
    for (final raw in [
      '8h e 20h',
      'Manhã (8h)',
      'Antes de dormir',
      '24:00',
      '07:60'
    ]) {
      final parsed = parseScheduleInput(raw);
      expect(parsed.isValid, isFalse, reason: raw);
      expect(parsed.error, scheduleFormatError);
    }
  });
}
