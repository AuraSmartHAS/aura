/**
 * O "Hoje com a Maria": o que a família lê sai destas regras, não da tela.
 * Mesmos cenários de `care_today_builder_test.dart` (Flutter) — as duas telas
 * têm que dizer a mesma coisa sobre o mesmo dia.
 */
import type { CareSignal, MedicationRecord } from '../api';
import {
  careAgo,
  careClock,
  emergencyOutcome,
  emergencyReadIsStale,
  isOpenEmergency,
  medicationsToday,
  nextEmergencyStep,
  takenLine,
  timeline,
} from '../careToday';

// 12:40 local de 7/out. Datas montadas em hora local: o teste não depende do fuso.
const now = new Date(2026, 9, 7, 12, 40);
const at = (h: number, m = 0, day = 7) => new Date(2026, 9, day, h, m);

const med = (over: Partial<MedicationRecord>): MedicationRecord => ({
  id: 'med',
  homeId: 'h',
  name: 'Remédio',
  dosage: null,
  schedule: [],
  notes: null,
  active: true,
  stockDoses: null,
  ...over,
});

const losartana = med({ id: 'med-los', name: 'Losartana', schedule: ['08:00'] });
const levodopa = med({ id: 'med-lev', name: 'Levodopa', schedule: ['06:00', '12:00', '18:00'] });

const dose = (id: string, medId: string, when: Date, over: { taken?: boolean; source?: string } = {}): CareSignal => ({
  id,
  type: 'adherence',
  source: over.source ?? 'voice',
  value: { medicationId: medId, taken: over.taken ?? true },
  capturedAt: when.toISOString(),
});

const event = (id: string, name: string, when: Date, place?: string, source = 'voice'): CareSignal => ({
  id,
  type: 'mobility',
  source,
  value: { event: name, ...(place ? { place } : {}) },
  capturedAt: when.toISOString(),
});

describe('medicationsToday', () => {
  it('dose confirmada hoje: completa, com horário e origem', () => {
    const [item] = medicationsToday([losartana], [dose('1', 'med-los', at(12, 34))], now);

    expect(item.status).toBe('complete');
    expect(item.takenCount).toBe(1);
    expect(item.nextTime).toBeNull();
    expect(item.lastTakenAt).toEqual(at(12, 34));
    expect(item.lastSource).toBe('voice');
    expect(takenLine(item, now)).toBe('Tomou às 12:34 · por voz');
  });

  it('horário passou sem confirmação: atrasada, e o próximo é o pendente', () => {
    const [item] = medicationsToday([losartana], [], now);

    expect(item.status).toBe('late');
    expect(item.nextTime).toBe('08:00');
  });

  it('várias doses: 1 de 3 às 12:40 com 2 horários passados está atrasada', () => {
    const [item] = medicationsToday([levodopa], [dose('1', 'med-lev', at(6, 5))], now);

    expect(item.takenCount).toBe(1);
    expect(item.status).toBe('late');
    expect(item.nextTime).toBe('12:00');
  });

  it('em dia: tomou as que já passaram e a próxima ainda não chegou', () => {
    const [item] = medicationsToday(
      [levodopa],
      [dose('1', 'med-lev', at(6, 5)), dose('2', 'med-lev', at(12, 10))],
      now,
    );

    expect(item.status).toBe('onTrack');
    expect(item.nextTime).toBe('18:00');
  });

  it('dose de ontem não conta para hoje', () => {
    const [item] = medicationsToday([losartana], [dose('1', 'med-los', at(8, 2, 6))], now);

    expect(item.takenCount).toBe(0);
    expect(item.status).toBe('late');
  });

  it('confirmações em excesso não passam do número de doses do dia', () => {
    const [item] = medicationsToday(
      [losartana],
      [dose('1', 'med-los', at(9)), dose('2', 'med-los', at(10))],
      now,
    );

    expect(item.takenCount).toBe(1);
  });

  it('repetir a fala não fecha o dia: 08:05 e 09:30 cobrem só o horário das 08:00, e às 21:00 a dose das 20:00 está atrasada', () => {
    const metformina = med({ id: 'med-met', name: 'Metformina', schedule: ['08:00', '20:00'] });

    const [item] = medicationsToday(
      [metformina],
      [dose('1', 'med-met', at(8, 5)), dose('2', 'med-met', at(9, 30))],
      at(21),
    );

    expect(item.takenCount).toBe(1);
    expect(item.status).toBe('late');
    expect(item.nextTime).toBe('20:00');
  });

  it('dose tomada cedo cobre o horário mais próximo (11:50 é a das 12:00)', () => {
    const [item] = medicationsToday(
      [levodopa],
      [dose('1', 'med-lev', at(6, 5)), dose('2', 'med-lev', at(11, 50))],
      now,
    );

    expect(item.takenCount).toBe(2);
    expect(item.status).toBe('onTrack');
    expect(item.nextTime).toBe('18:00');
  });

  it('folga de 30 min: no horário em ponto ainda não é atraso', () => {
    const [noPonto] = medicationsToday([losartana], [], at(8, 10));
    const [passouDaFolga] = medicationsToday([losartana], [], at(8, 30));

    expect(noPonto.status).toBe('onTrack');
    expect(noPonto.nextTime).toBe('08:00');
    expect(passouDaFolga.status).toBe('late');
  });

  it('horário legado ("8h") não é horário de dose: vira "quando necessário"', () => {
    const [item] = medicationsToday([med({ id: 'x', name: 'Legado', schedule: ['8h'] })], [], now);

    expect(item.status).toBe('asNeeded');
  });

  it('empate de distância cobre o horário mais cedo (10:00 entre 08:00 e 12:00)', () => {
    const doisHorarios = med({ id: 'med-dois', name: 'Dois', schedule: ['08:00', '12:00'] });

    const [item] = medicationsToday([doisHorarios], [dose('1', 'med-dois', at(10))], now);

    // 10:00 cobre as 08:00; as 12:00 (já passaram da folga às 12:40) seguem pendentes
    expect(item.takenCount).toBe(1);
    expect(item.status).toBe('late');
    expect(item.nextTime).toBe('12:00');
  });

  it('confirmação depois do último horário cobre o último', () => {
    const [item] = medicationsToday([losartana], [dose('1', 'med-los', at(11, 30))], now);

    expect(item.status).toBe('complete');
  });

  it('horário malformado ("8x:30") não é horário de dose', () => {
    const [item] = medicationsToday([med({ id: 'x', name: 'Ruim', schedule: ['8x:30'] })], [], now);

    expect(item.status).toBe('asNeeded');
  });

  it('"não tomei" depois da última confirmação marca recusa; confirmar depois limpa', () => {
    const [recusou] = medicationsToday([losartana], [dose('1', 'med-los', at(9), { taken: false })], now);
    const [tomouDepois] = medicationsToday(
      [losartana],
      [dose('1', 'med-los', at(9), { taken: false }), dose('2', 'med-los', at(10))],
      now,
    );

    expect(recusou.declinedToday).toBe(true);
    expect(tomouDepois.declinedToday).toBe(false);
  });

  it('sem horário fixo é "quando necessário"; remédio inativo some', () => {
    const items = medicationsToday(
      [med({ id: 'prn', name: 'Dipirona' }), med({ id: 'old', name: 'Antigo', schedule: ['08:00'], active: false })],
      [],
      now,
    );

    expect(items).toHaveLength(1);
    expect(items[0].status).toBe('asNeeded');
  });
});

describe('timeline', () => {
  it('traduz dose, sintoma com local e SOS, do mais novo ao mais antigo', () => {
    const items = timeline(
      [
        event('a', 'near_fall', at(12, 20), 'bathroom'),
        dose('b', 'med-los', at(12, 34)),
        { id: 'c', type: 'mobility', source: 'usage', value: { event: 'sos', channel: 'voice' }, capturedAt: at(12, 38).toISOString() },
      ],
      [losartana],
      'Maria',
    );

    expect(items.map((i) => i.title)).toEqual([
      'Maria pediu ajuda (SOS)',
      'Maria confirmou Losartana',
      'Maria relatou uma quase-queda no banheiro',
    ]);
    expect(items.map((i) => i.source)).toEqual(['voice', 'voice', 'voice']);
    expect(items.map((i) => i.concerning)).toEqual([true, false, true]);
  });

  it('origem do toque aparece como "no app"', () => {
    const [item] = timeline([dose('1', 'med-los', at(9), { source: 'self_report' })], [losartana], 'Maria');

    expect(item.source).toBe('app');
  });

  it('dose negada vira "disse que não tomou" e pede atenção', () => {
    const [item] = timeline([dose('1', 'med-los', at(9), { taken: false })], [losartana], 'Maria');

    expect(item.title).toBe('Maria disse que não tomou Losartana');
    expect(item.concerning).toBe(true);
  });

  it('evento e local desconhecidos aparecem legíveis, nunca crus', () => {
    const [item] = timeline([event('1', 'strange_thing', at(9), 'garage')], [], 'Maria');

    expect(item.title).toBe('Maria relatou strange thing em garage');
  });

  it('leitura do relógio fica de fora e o limite vale', () => {
    const wearable: CareSignal = {
      id: 'w',
      type: 'vitals',
      source: 'wearable',
      value: { steps: 1800 },
      capturedAt: at(12).toISOString(),
    };
    const doses = Array.from({ length: 10 }, (_, i) => dose(`d${i}`, 'med-los', at(8, i)));

    const items = timeline([wearable, ...doses], [losartana], 'Maria', 4);

    expect(items).toHaveLength(4);
    expect(items.some((i) => i.id === 'w')).toBe(false);
  });

  it('remédio que não está na lista não derruba a linha do tempo', () => {
    const [item] = timeline([dose('1', 'desconhecido', at(9))], [], 'Maria');

    expect(item.title).toBe('Maria confirmou um remédio');
  });
});

describe('horas na língua da família', () => {
  it('careClock: hoje, ontem e antes', () => {
    expect(careClock(at(12, 34), now)).toBe('12:34');
    expect(careClock(at(8, 2, 6), now)).toBe('ontem 08:02');
    expect(careClock(at(8, 2, 3), now)).toBe('03/10 08:02');
  });

  it('careAgo: agora, minutos, horas e relógio', () => {
    expect(careAgo(at(12, 40), now)).toBe('agora');
    expect(careAgo(at(12, 35), now)).toBe('há 5 min');
    expect(careAgo(at(10, 40), now)).toBe('há 2 h');
    expect(careAgo(at(8, 2, 6), now)).toBe('ontem 08:02');
  });
});

describe('desfecho do SOS na tela da família', () => {
  const aberto = { emergencyId: 'em-1', state: 'dispatched', createdAt: at(12, 38).toISOString() };
  const LINGER = 45_000;

  it('SOS em aberto no servidor: mostra', () => {
    expect(nextEmergencyStep(null, aberto, null, 0, LINGER)).toEqual({ kind: 'show', emergency: aberto });
  });

  it('nada em aberto e nada na tela: nada a fazer', () => {
    expect(nextEmergencyStep(null, null, null, 0, LINGER)).toEqual({ kind: 'keep' });
  });

  it('estava em aberto e deixou de estar: pergunta como terminou, não some calado', () => {
    expect(nextEmergencyStep(aberto, null, null, 0, LINGER)).toEqual({ kind: 'lookup', emergencyId: 'em-1' });
  });

  it('desfecho fica pelo tempo de leitura e depois some', () => {
    const confirmado = { ...aberto, state: 'acknowledged' };

    expect(nextEmergencyStep(confirmado, null, 1_000, 1_000 + LINGER - 1, LINGER)).toEqual({ kind: 'keep' });
    expect(nextEmergencyStep(confirmado, null, 1_000, 1_000 + LINGER, LINGER)).toEqual({ kind: 'clear' });
  });

  it('o desfecho sem horário herda o do pedido (o ack e o estado não o repetem)', () => {
    const resultado = emergencyOutcome(aberto, { emergencyId: 'em-1', state: 'acknowledged', acknowledgedByName: 'Bruno' });

    expect(resultado.state).toBe('acknowledged');
    expect(resultado.acknowledgedByName).toBe('Bruno');
    expect(resultado.createdAt).toBe(aberto.createdAt);
  });

  it('sem resposta útil do servidor vira "encerrado", sem inventar um desfecho', () => {
    expect(emergencyOutcome(aberto, null).state).toBe('closed');
    // O servidor ainda diz "em aberto": também não vira desfecho.
    expect(emergencyOutcome(aberto, { ...aberto, state: 'escalated' }).state).toBe('closed');
  });

  it('isOpenEmergency distingue o que pede resposta do que já terminou', () => {
    expect(['waiting_cancel', 'dispatched', 'escalated'].map((state) => isOpenEmergency({ state }))).toEqual([true, true, true]);
    expect(['acknowledged', 'cancelled', 'closed'].map((state) => isOpenEmergency({ state }))).toEqual([false, false, false]);
  });
});

describe('corrida entre o polling e o "estou indo"', () => {
  it('leitura iniciada antes da confirmação não se aplica depois dela', () => {
    // poll começa na época 0; o toque em "estou indo" a leva a 1 (e a 2 ao terminar)
    expect(emergencyReadIsStale(0, 2, false)).toBe(true);
  });

  it('enquanto o ack está em andamento, nenhuma leitura se aplica', () => {
    expect(emergencyReadIsStale(1, 1, true)).toBe(true);
  });

  it('sem transição local, a leitura vale', () => {
    expect(emergencyReadIsStale(2, 2, false)).toBe(false);
  });
});
