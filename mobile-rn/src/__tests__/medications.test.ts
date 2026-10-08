/**
 * Medicamentos da família: os mesmos cenários de `schedule_input_test.dart`,
 * `day_period_grouping_test.dart` e do mapper (Flutter). O que a cuidadora cadastra
 * num app tem que aparecer igual no outro.
 */
import type { MedicationRecord } from '../api';
import {
  appendSchedule,
  createBody,
  groupByDayPeriod,
  minutesOfDay,
  parseScheduleInput,
  periodOf,
  scheduleFormatError,
  stockFromText,
  trimmedOrNull,
  updateBody,
  type MedicationPeriod,
} from '../medications';

const med = (name: string, schedule: string[]): MedicationRecord => ({
  id: name,
  homeId: 'home-1',
  name,
  dosage: null,
  schedule,
  notes: null,
  active: true,
  stockDoses: null,
});

/** Resumo legível: período -> ["Nome 08:00,09:00", ...]. */
const summary = (meds: MedicationRecord[]) =>
  Object.fromEntries(
    groupByDayPeriod(meds).map((g) => [
      g.period,
      g.entries.map((e) => `${e.medication.name}${e.times.length === 0 ? '' : ` ${e.times.join(',')}`}`),
    ]),
  ) as Partial<Record<MedicationPeriod, string[]>>;

describe('parseScheduleInput', () => {
  it('aceita HH:mm separados por vírgula, espaço ou "e"', () => {
    const parsed = parseScheduleInput('20:00, 08:00 e 14:00 22:00');

    expect(parsed.error).toBeNull();
    expect(parsed.times).toEqual(['08:00', '14:00', '20:00', '22:00']);
  });

  it('normaliza 8:00 para 08:00 e remove repetidos', () => {
    expect(parseScheduleInput('8:00, 08:00').times).toEqual(['08:00']);
  });

  it('campo vazio é válido e significa sem horário fixo', () => {
    const parsed = parseScheduleInput('   ');

    expect(parsed.error).toBeNull();
    expect(parsed.times).toEqual([]);
  });

  it('texto livre e hora fora do relógio são recusados', () => {
    for (const raw of ['8h e 20h', 'Manhã (8h)', 'Antes de dormir', '24:00', '07:60']) {
      expect(parseScheduleInput(raw).error).toBe(scheduleFormatError);
    }
  });
});

describe('periodOf (bordas)', () => {
  it('Manhã de 05:00 a 11:59', () => {
    expect(['05:00', '08:00', '11:59'].map(periodOf)).toEqual(['morning', 'morning', 'morning']);
  });

  it('Tarde de 12:00 a 17:59', () => {
    expect(['12:00', '17:59'].map(periodOf)).toEqual(['afternoon', 'afternoon']);
  });

  it('Noite de 18:00 a 04:59, atravessando a meia-noite', () => {
    expect(['18:00', '23:59', '00:00', '04:59'].map(periodOf)).toEqual(['evening', 'evening', 'evening', 'evening']);
  });

  it('texto legado ou horário inválido não é período', () => {
    for (const raw of ['8h', 'manhã', '', '24:00', '12:60', 'abc']) {
      expect(periodOf(raw)).toBeNull();
    }
  });

  it('minutesOfDay tolera segundos e recusa o que não é hora', () => {
    expect(minutesOfDay('08:30:15')).toBe(8 * 60 + 30);
    expect(minutesOfDay('8h')).toBeNull();
  });
});

describe('groupByDayPeriod', () => {
  it('08:00 vai para Manhã, não para "Sem horário definido"', () => {
    expect(summary([med('Losartana', ['08:00'])])).toEqual({ morning: ['Losartana 08:00'] });
  });

  it('grupos na ordem do dia e medicamentos por horário', () => {
    const result = summary([
      med('Sem hora', []),
      med('Noturno', ['22:00']),
      med('Tarde', ['14:00']),
      med('Cedo', ['05:00']),
      med('Madrugada', ['00:30']),
      med('Antes do almoço', ['11:59']),
    ]);

    expect(Object.keys(result)).toEqual(['morning', 'afternoon', 'evening', 'unscheduled']);
    expect(result.morning).toEqual(['Cedo 05:00', 'Antes do almoço 11:59']);
    // 00:30 ainda é "Noite" e vem depois das 22:00.
    expect(result.evening).toEqual(['Noturno 22:00', 'Madrugada 00:30']);
    expect(result.unscheduled).toEqual(['Sem hora']);
  });

  it('horários em períodos diferentes aparecem em cada período', () => {
    expect(summary([med('Metformina', ['20:00', '08:00', '13:00', '07:00'])])).toEqual({
      morning: ['Metformina 07:00,08:00'],
      afternoon: ['Metformina 13:00'],
      evening: ['Metformina 20:00'],
    });
  });

  it('bordas 17:59/18:00 e 04:59/05:00 separam os períodos', () => {
    const result = summary([med('A', ['17:59', '18:00']), med('B', ['04:59', '05:00'])]);

    expect(result.morning).toEqual(['B 05:00']);
    expect(result.afternoon).toEqual(['A 17:59']);
    expect(result.evening).toEqual(['A 18:00', 'B 04:59']);
  });

  it('texto legado cai em "Sem horário definido" sem quebrar', () => {
    expect(summary([med('Legado', ['8h', 'manhã']), med('Misto', ['8h', '09:00'])])).toEqual({
      morning: ['Misto 09:00'],
      unscheduled: ['Legado'],
    });
  });

  it('lista vazia não gera grupos', () => {
    expect(groupByDayPeriod([])).toEqual([]);
  });
});

describe('corpos das rotas', () => {
  const input = { name: 'Losartana', dosage: '50mg', times: ['08:00'], notes: null, stockDoses: 30 };

  it('criar omite o campo ausente', () => {
    expect(createBody(input)).toEqual({ name: 'Losartana', dosage: '50mg', schedule: ['08:00'], stockDoses: 30 });
    expect(createBody({ ...input, dosage: null, stockDoses: null })).toEqual({
      name: 'Losartana',
      schedule: ['08:00'],
    });
  });

  it('editar manda vazio para limpar o que a cuidadora apagou (o servidor atualiza parcial)', () => {
    expect(updateBody({ ...input, dosage: null })).toEqual({
      name: 'Losartana',
      dosage: '',
      schedule: ['08:00'],
      notes: '',
      stockDoses: 30,
    });
  });

  it('editar sem estoque não manda o campo: o estoque não se limpa, só se altera', () => {
    expect(updateBody({ ...input, stockDoses: null })).not.toHaveProperty('stockDoses');
  });
});

describe('texto do formulário', () => {
  it('trimmedOrNull e stockFromText', () => {
    expect(trimmedOrNull('  ')).toBeNull();
    expect(trimmedOrNull(' 50mg ')).toBe('50mg');
    expect(stockFromText('30')).toBe(30);
    expect(stockFromText('')).toBeNull();
    expect(stockFromText('3,5')).toBeNull();
    expect(stockFromText('-2')).toBeNull();
  });

  it('a sugestão de horário se acrescenta sem repetir', () => {
    expect(appendSchedule('', '08:00')).toBe('08:00');
    expect(appendSchedule('08:00', '20:00')).toBe('08:00, 20:00');
    expect(appendSchedule('08:00, 20:00', '08:00')).toBe('08:00, 20:00');
  });
});
