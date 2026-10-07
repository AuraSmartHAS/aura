/**
 * O "Hoje" e a linha do tempo da família, calculados a partir dos sinais da casa.
 * Espelho de `caregiver_dashboard/domain/care_today_builder.dart` (Flutter): as
 * duas telas têm que dizer a mesma coisa sobre o mesmo dia. Puro — sem rede e
 * sem relógio escondido: quem chama passa o `now`.
 */
import type { ActiveEmergency, CareSignal, MedicationRecord } from './api';

/** Eventos do agente de voz e do app, na frase da família. Evento novo se traduz aqui. */
export const careEventLabels: Record<string, string> = {
  near_fall: 'uma quase-queda',
  fall: 'uma queda',
  dizziness: 'tontura',
  tremor_worse: 'tremor mais forte que o normal',
  pain: 'dor',
  poor_sleep: 'uma noite mal dormida',
  night_trip: 'idas noturnas ao banheiro',
  forgetfulness: 'esquecimento',
  confusion: 'confusão na fala',
  sadness: 'tristeza',
  slippery_floor: 'piso escorregadio',
  poor_air: 'ar de má qualidade',
};

/** Onde aconteceu, já com a preposição. */
export const carePlaceLabels: Record<string, string> = {
  bathroom: 'no banheiro',
  kitchen: 'na cozinha',
  bedroom: 'no quarto',
  living_room: 'na sala',
  stairs: 'na escada',
};

export type ActivitySource = 'voice' | 'app' | 'wearable';

export const sourceLabel: Record<ActivitySource, string> = {
  voice: 'por voz',
  app: 'no app',
  wearable: 'pelo relógio',
};

export type ActivityKind = 'dose' | 'symptom' | 'sos';

export interface CareActivity {
  id: string;
  kind: ActivityKind;
  title: string;
  source: ActivitySource;
  occurredAt: Date;
  /** Pede atenção da família (sintoma, SOS, dose recusada). */
  concerning: boolean;
}

export type DoseStatus = 'complete' | 'onTrack' | 'late' | 'asNeeded';

export interface MedicationToday {
  medication: MedicationRecord;
  status: DoseStatus;
  takenCount: number;
  dosesPerDay: number;
  /** Próximo horário ainda sem confirmação (`HH:mm`). */
  nextTime: string | null;
  lastTakenAt: Date | null;
  lastSource: ActivitySource | null;
  /** Hoje a Maria disse que NÃO tomou e não confirmou depois. */
  declinedToday: boolean;
}

const humanize = (code: string): string => code.replace(/_/g, ' ');

const sameDay = (a: Date, b: Date): boolean =>
  a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

function minutesOf(hhmm: string): number | null {
  // Ancorado: "8x:30" não é horário (o parseInt solto o leria como 8 h).
  const match = /^(\d{1,2}):(\d{2})$/.exec(hhmm.trim());
  if (!match) return null;
  const h = Number.parseInt(match[1], 10);
  const m = Number.parseInt(match[2], 10);
  if (h > 23 || m > 59) return null;
  return h * 60 + m;
}

/** Início do dia anterior (hora local): o recorte de sinais que cobre "hoje" com folga. */
export function startOfYesterday(now: Date): Date {
  return new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
}

/** Início do dia (hora local). */
export function startOfToday(now: Date): Date {
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

function sourceOf(signal: CareSignal): ActivitySource {
  if (signal.source === 'voice') return 'voice';
  if (signal.source === 'wearable') return 'wearable';
  return 'app';
}

const byNewest = (a: CareSignal, b: CareSignal): number =>
  new Date(b.capturedAt).getTime() - new Date(a.capturedAt).getTime();

/**
 * Quanto depois do horário a dose passa a contar como atrasada. Sem folga, o painel acenderia
 * "atrasada" no minuto exato de cada dose — alarme que ensina a família a ignorar o indicador.
 */
export const GRACE_MINUTES = 30;

/**
 * Situação de cada remédio ativo hoje (`now` em hora local).
 *
 * Cada confirmação "tomei" cobre o horário MAIS PRÓXIMO dela; um horário coberto por duas
 * confirmações conta uma vez. É isto que impede a Maria, repetindo a fala ("tomei a levodopa" às
 * 08:05 e de novo às 09:30), de fechar o dia e esconder a dose das 20:00 que ainda não foi tomada.
 */
export function medicationsToday(
  medications: MedicationRecord[],
  signals: CareSignal[],
  now: Date,
): MedicationToday[] {
  const nowMinutes = now.getHours() * 60 + now.getMinutes();

  return medications
    .filter((m) => m.active)
    .map((med) => {
      const mine = signals
        .filter(
          (s) =>
            s.type === 'adherence' &&
            s.value.medicationId === med.id &&
            sameDay(new Date(s.capturedAt), now),
        )
        .sort(byNewest);

      const taken = mine.filter((s) => s.value.taken === true);
      const declined = mine.filter((s) => s.value.taken === false);

      // Só horários legíveis: texto legado ("8h") não é horário de dose.
      const slots = med.schedule
        .map((time) => ({ time, minutes: minutesOf(time) }))
        .filter((slot): slot is { time: string; minutes: number } => slot.minutes !== null)
        .sort((a, b) => a.minutes - b.minutes);

      const covered = new Set<number>();
      if (slots.length > 0) {
        for (const signal of taken) {
          const at = new Date(signal.capturedAt);
          const minute = at.getHours() * 60 + at.getMinutes();
          let nearest = 0;
          for (let i = 1; i < slots.length; i++) {
            if (Math.abs(slots[i].minutes - minute) < Math.abs(slots[nearest].minutes - minute)) nearest = i;
          }
          covered.add(nearest);
        }
      }

      const perDay = slots.length;
      const takenCount = perDay === 0 ? (taken.length === 0 ? 0 : 1) : covered.size;
      const uncovered = slots.map((_, i) => i).filter((i) => !covered.has(i));

      let status: DoseStatus;
      if (perDay === 0) status = 'asNeeded';
      else if (uncovered.length === 0) status = 'complete';
      else if (uncovered.some((i) => slots[i].minutes + GRACE_MINUTES <= nowMinutes)) status = 'late';
      else status = 'onTrack';

      // "Não tomei" só pesa se não houve confirmação depois dele.
      const declinedToday =
        declined.length > 0 &&
        (taken.length === 0 ||
          new Date(declined[0].capturedAt).getTime() > new Date(taken[0].capturedAt).getTime());

      return {
        medication: med,
        status,
        takenCount,
        dosesPerDay: perDay,
        nextTime: uncovered.length === 0 ? null : slots[uncovered[0]].time,
        lastTakenAt: taken.length === 0 ? null : new Date(taken[0].capturedAt),
        lastSource: taken.length === 0 ? null : sourceOf(taken[0]),
        declinedToday,
      };
    });
}

function activityOf(
  signal: CareSignal,
  meds: Map<string, MedicationRecord>,
  who: string,
): CareActivity | null {
  if (signal.source === 'wearable') return null;
  const at = new Date(signal.capturedAt);

  const medicationId = signal.value.medicationId;
  if (signal.type === 'adherence' && typeof medicationId === 'string') {
    const name = meds.get(medicationId)?.name ?? 'um remédio';
    const taken = signal.value.taken !== false;
    return {
      id: signal.id,
      kind: 'dose',
      title: taken ? `${who} confirmou ${name}` : `${who} disse que não tomou ${name}`,
      source: sourceOf(signal),
      occurredAt: at,
      concerning: !taken,
    };
  }

  const event = signal.value.event;
  if (typeof event === 'string') {
    if (event === 'sos') {
      return {
        id: signal.id,
        kind: 'sos',
        title: `${who} pediu ajuda (SOS)`,
        source: signal.value.channel === 'voice' ? 'voice' : 'app',
        occurredAt: at,
        concerning: true,
      };
    }
    const what = careEventLabels[event] ?? humanize(event);
    const place = signal.value.place;
    const placeText =
      typeof place === 'string' ? (carePlaceLabels[place] ?? `em ${humanize(place)}`) : null;
    return {
      id: signal.id,
      kind: 'symptom',
      title: `${who} relatou ${what}${placeText === null ? '' : ` ${placeText}`}`,
      source: sourceOf(signal),
      occurredAt: at,
      concerning: true,
    };
  }
  return null;
}

/**
 * Os eventos mais recentes, do mais novo ao mais antigo. Leituras do relógio
 * ficam de fora: a linha do tempo é sobre o que a Maria disse e fez.
 */
export function timeline(
  signals: CareSignal[],
  medications: MedicationRecord[],
  patientFirstName: string,
  limit = 6,
): CareActivity[] {
  const meds = new Map(medications.map((m) => [m.id, m]));
  const out: CareActivity[] = [];
  for (const signal of [...signals].sort(byNewest)) {
    const activity = activityOf(signal, meds, patientFirstName);
    if (activity) out.push(activity);
    if (out.length === limit) break;
  }
  return out;
}

const two = (n: number): string => String(n).padStart(2, '0');

/** "14:32" hoje; "ontem 14:32"; "05/10 14:32" antes disso. */
export function careClock(at: Date, now: Date): string {
  const hhmm = `${two(at.getHours())}:${two(at.getMinutes())}`;
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const day = new Date(at.getFullYear(), at.getMonth(), at.getDate());
  const diff = Math.round((today.getTime() - day.getTime()) / 86_400_000);
  if (diff === 0) return hhmm;
  if (diff === 1) return `ontem ${hhmm}`;
  return `${two(at.getDate())}/${two(at.getMonth() + 1)} ${hhmm}`;
}

/** "agora", "há 5 min", "há 2 h", "ontem 14:32"… */
export function careAgo(at: Date, now: Date): string {
  const minutes = Math.floor((now.getTime() - at.getTime()) / 60_000);
  if (minutes < 1) return 'agora';
  if (minutes < 60) return `há ${minutes} min`;
  const hours = Math.floor(minutes / 60);
  if (hours < 6) return `há ${hours} h`;
  return careClock(at, now);
}

/** "Tomou às 12:34 · por voz". */
export function takenLine(item: MedicationToday, now: Date): string {
  if (!item.lastTakenAt) return 'Tomou';
  const clock = careClock(item.lastTakenAt, now).replace('ontem ', '');
  return `Tomou às ${clock}${item.lastSource ? ` · ${sourceLabel[item.lastSource]}` : ''}`;
}

/** Quanto sobra no estoque, no singular/plural certo. */
export function stockLabel(doses: number): string {
  return `${doses} ${doses === 1 ? 'dose' : 'doses'}`;
}

/** Ainda pede resposta da família (waiting_cancel, dispatched ou escalated). */
export function isOpenEmergency(emergency: { state: string }): boolean {
  return emergency.state === 'waiting_cancel' || emergency.state === 'dispatched' || emergency.state === 'escalated';
}

/** O que fazer com o SOS na tela depois de perguntar ao servidor se há um em aberto. */
export type EmergencyStep =
  | { kind: 'show'; emergency: ActiveEmergency }
  | { kind: 'keep' }
  | { kind: 'clear' }
  /** Estava em aberto e deixou de estar: perguntar como terminou. */
  | { kind: 'lookup'; emergencyId: string };

/**
 * Transição da faixa de SOS (espelho de `DashboardBloc._applyEmergency`, Flutter).
 * `open` é o que o servidor acabou de dizer estar em aberto (ou null). Um desfecho (confirmado,
 * cancelado) fica na tela por `lingerMs`; um SOS que deixa de estar aberto NÃO some calado.
 */
export function nextEmergencyStep(
  current: ActiveEmergency | null,
  open: ActiveEmergency | null,
  resolvedAt: number | null,
  nowMs: number,
  lingerMs: number,
): EmergencyStep {
  if (open) return { kind: 'show', emergency: open };
  if (current === null) return { kind: 'keep' };
  if (!isOpenEmergency(current)) {
    return resolvedAt !== null && nowMs - resolvedAt >= lingerMs ? { kind: 'clear' } : { kind: 'keep' };
  }
  return { kind: 'lookup', emergencyId: current.emergencyId };
}

/**
 * A leitura de SOS que um poll trouxe é anterior a uma confirmação local ("estou indo")? Se começou
 * antes da transição, ou se há uma em andamento, ela não pode ser aplicada: faria a faixa negar uma
 * confirmação que o servidor já registrou (espelho de `_ackEpoch` no DashboardBloc, Flutter).
 */
export function emergencyReadIsStale(epochAtStart: number, epochNow: number, acknowledging: boolean): boolean {
  return epochAtStart !== epochNow || acknowledging;
}

/** Como um SOS que deixou de estar aberto terminou; sem resposta útil, "encerrado" — sem inventar. */
export function emergencyOutcome(current: ActiveEmergency, outcome: ActiveEmergency | null): ActiveEmergency {
  if (outcome === null || isOpenEmergency(outcome)) {
    return { emergencyId: current.emergencyId, state: 'closed', createdAt: current.createdAt };
  }
  // O estado não repete o horário do pedido: mantém o que já se sabia.
  return { ...outcome, createdAt: outcome.createdAt ?? current.createdAt };
}

/** Primeiro nome da paciente, para as frases da linha do tempo. */
export function firstName(full: string | null | undefined): string {
  const first = (full ?? '').trim().split(/\s+/)[0];
  return first ? first : 'A paciente';
}
