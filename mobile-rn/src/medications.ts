/**
 * Regras de Medicamentos da família: leitura do campo "Horários", períodos do dia e
 * corpos das rotas. Espelho de `medications/domain` e `medication_mapper.dart` (Flutter):
 * o que a cuidadora cadastra num app aparece igual no outro.
 */
import type { MedicationRecord } from './api';

export const scheduleFormatError =
  'Use horários no formato HH:mm, separados por vírgula (ex.: 08:00, 20:00).';

export interface ScheduleParse {
  times: string[];
  error: string | null;
}

const timePattern = /^(\d{1,2}):(\d{2})$/;
const separators = /[,;]|\s+e\s+|\s+/;

const pad = (n: number): string => String(n).padStart(2, '0');

/**
 * Lê "08:00, 20:00" (vírgula, ponto e vírgula, espaço ou " e ") em horários `HH:mm`
 * ordenados e sem repetição. "8:00" vira "08:00". Vazio é válido: "sem horário fixo".
 * O servidor só aceita `HH:mm` de 24h (400 no resto), então o formulário confere antes.
 */
export function parseScheduleInput(raw: string): ScheduleParse {
  const parts = raw
    .trim()
    .split(separators)
    .map((p) => p.trim())
    .filter((p) => p.length > 0);

  const times = new Set<string>();
  for (const part of parts) {
    const match = timePattern.exec(part);
    if (!match) return { times: [], error: scheduleFormatError };
    const hour = Number.parseInt(match[1], 10);
    const minute = Number.parseInt(match[2], 10);
    if (hour > 23 || minute > 59) return { times: [], error: scheduleFormatError };
    times.add(`${pad(hour)}:${pad(minute)}`);
  }
  return { times: [...times].sort(), error: null };
}

export type MedicationPeriod = 'morning' | 'afternoon' | 'evening' | 'unscheduled';

const hhmm = /^(\d{1,2}):(\d{2})(?::\d{2})?$/;

/** Minutos desde a meia-noite de um `HH:mm` (segundos tolerados), ou null se não for hora de 24h. */
export function minutesOfDay(time: string): number | null {
  const match = hhmm.exec(time.trim());
  if (!match) return null;
  const hour = Number.parseInt(match[1], 10);
  const minute = Number.parseInt(match[2], 10);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

/**
 * Manhã 05:00–11:59, Tarde 12:00–17:59, Noite 18:00–04:59 (atravessa a meia-noite).
 * Texto legado ("8h") e hora inválida não são período.
 */
export function periodOf(time: string): Exclude<MedicationPeriod, 'unscheduled'> | null {
  const minutes = minutesOfDay(time);
  if (minutes === null) return null;
  if (minutes < 5 * 60 || minutes >= 18 * 60) return 'evening';
  if (minutes < 12 * 60) return 'morning';
  return 'afternoon';
}

/** Ordem que segue o dia a partir das 05:00: 00:30 ainda é "Noite" e vem depois das 23:00. */
const dayOrder = (minutes: number): number => (minutes < 5 * 60 ? minutes + 24 * 60 : minutes);

export interface PeriodEntry {
  medication: MedicationRecord;
  /** Só os horários deste período (`HH:mm`, ordenados). Vazio em "sem horário". */
  times: string[];
}

export interface PeriodGroup {
  period: MedicationPeriod;
  entries: PeriodEntry[];
}

const periodOrder: MedicationPeriod[] = ['morning', 'afternoon', 'evening', 'unscheduled'];

/**
 * Grupos não vazios na ordem do dia; dentro de cada um, remédios pelo primeiro horário daquele
 * período (depois pelo nome). Um remédio com horários em vários períodos aparece em cada um.
 */
export function groupByDayPeriod(medications: MedicationRecord[]): PeriodGroup[] {
  const buckets = new Map<MedicationPeriod, { order: number; entry: PeriodEntry }[]>();
  const push = (period: MedicationPeriod, order: number, entry: PeriodEntry) => {
    const list = buckets.get(period) ?? [];
    list.push({ order, entry });
    buckets.set(period, list);
  };

  for (const medication of medications) {
    const byPeriod = new Map<MedicationPeriod, { order: number; time: string }[]>();
    for (const raw of medication.schedule) {
      const minutes = minutesOfDay(raw);
      if (minutes === null) continue;
      const normalized = `${pad(Math.floor(minutes / 60))}:${pad(minutes % 60)}`;
      const period = periodOf(normalized) as MedicationPeriod;
      const list = byPeriod.get(period) ?? [];
      list.push({ order: dayOrder(minutes), time: normalized });
      byPeriod.set(period, list);
    }

    if (byPeriod.size === 0) {
      push('unscheduled', 1 << 30, { medication, times: [] });
      continue;
    }
    for (const [period, times] of byPeriod) {
      times.sort((a, b) => a.order - b.order);
      const unique = [...new Set(times.map((t) => t.time))];
      push(period, times[0].order, { medication, times: unique });
    }
  }

  const groups: PeriodGroup[] = [];
  for (const period of periodOrder) {
    const items = buckets.get(period);
    if (!items) continue;
    items.sort(
      (a, b) =>
        a.order - b.order ||
        a.entry.medication.name.toLowerCase().localeCompare(b.entry.medication.name.toLowerCase()),
    );
    groups.push({ period, entries: items.map((i) => i.entry) });
  }
  return groups;
}

export const periodLabel: Record<MedicationPeriod, string> = {
  morning: 'Manhã',
  afternoon: 'Tarde',
  evening: 'Noite',
  unscheduled: 'Sem horário definido',
};

/** O que a cuidadora preenche no formulário. */
export interface MedicationInput {
  name: string;
  dosage: string | null;
  times: string[];
  notes: string | null;
  stockDoses: number | null;
}

/** Corpo do `POST /homes/{homeId}/medications`: campo ausente é omitido. */
export function createBody(input: MedicationInput): Record<string, unknown> {
  return {
    name: input.name,
    ...(input.dosage !== null ? { dosage: input.dosage } : {}),
    schedule: input.times,
    ...(input.notes !== null ? { notes: input.notes } : {}),
    ...(input.stockDoses !== null ? { stockDoses: input.stockDoses } : {}),
  };
}

/**
 * Corpo do `PUT /medications/{id}`. O servidor faz atualização parcial (campo nulo fica como
 * está), então o que a cuidadora apagou vai como vazio para realmente limpar. O estoque não
 * se limpa, só se altera.
 */
export function updateBody(input: MedicationInput): Record<string, unknown> {
  return {
    name: input.name,
    dosage: input.dosage ?? '',
    schedule: input.times,
    notes: input.notes ?? '',
    ...(input.stockDoses !== null ? { stockDoses: input.stockDoses } : {}),
  };
}

/** Texto do formulário já limpo: vazio vira null. */
export function trimmedOrNull(value: string): string | null {
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

/** Estoque digitado: só dígitos; vazio ou inválido vira null (sem estoque controlado). */
export function stockFromText(value: string): number | null {
  const digits = value.trim();
  if (!/^\d+$/.test(digits)) return null;
  return Number.parseInt(digits, 10);
}

/** Acrescenta uma sugestão (`HH:mm`) ao campo sem repetir o que já está nele. */
export function appendSchedule(current: string, time: string): string {
  const trimmed = current.trim();
  if (trimmed.split(/[,;\s]+/).includes(time)) return trimmed;
  return trimmed.length === 0 ? time : `${trimmed}, ${time}`;
}
