import 'package:aura/features/caregiver_dashboard/domain/care_today_builder.dart';
import 'package:aura/features/caregiver_dashboard/domain/entities/care_signal.dart';
import 'package:aura/features/caregiver_dashboard/domain/entities/care_today.dart';
import 'package:aura/features/medications/domain/entities/medication.dart';
import 'package:flutter_test/flutter_test.dart';

/// O "Hoje com a Maria": o que a família lê sai destas regras, não da tela.
void main() {
  // 12:40 local de 7/out. Os sinais são montados em hora local para o teste
  // não depender do fuso da máquina.
  final now = DateTime(2026, 10, 7, 12, 40);

  const losartana = Medication(
    id: 'med-los',
    homeId: 'h',
    name: 'Losartana',
    times: ['08:00'],
  );
  const levodopa = Medication(
    id: 'med-lev',
    homeId: 'h',
    name: 'Levodopa',
    times: ['06:00', '12:00', '18:00'],
  );
  const prn = Medication(id: 'med-prn', homeId: 'h', name: 'Dipirona');
  const inactive = Medication(
      id: 'med-old', homeId: 'h', name: 'Antigo', times: ['08:00'], active: false);

  CareSignal dose(String id, String medId, DateTime at,
          {bool taken = true, String source = 'voice'}) =>
      CareSignal(
        id: id,
        type: 'adherence',
        source: source,
        value: {'medicationId': medId, 'taken': taken},
        capturedAt: at,
      );

  CareSignal event(String id, String event, DateTime at,
          {String? place, String source = 'voice'}) =>
      CareSignal(
        id: id,
        type: 'mobility',
        source: source,
        value: {'event': event, if (place != null) 'place': place},
        capturedAt: at,
      );

  group('medicationsToday', () {
    test('dose confirmada hoje: completa, com horário e origem', () {
      final result = CareTodayBuilder.medicationsToday(
        [losartana],
        [dose('1', 'med-los', DateTime(2026, 10, 7, 12, 34))],
        now,
      );

      expect(result.single.status, DoseStatus.complete);
      expect(result.single.takenCount, 1);
      expect(result.single.nextTime, isNull);
      expect(result.single.lastTakenAt, DateTime(2026, 10, 7, 12, 34));
      expect(result.single.lastSource, ActivitySource.voice);
    });

    test('horário passou sem confirmação: atrasada, e o próximo é o pendente',
        () {
      final result = CareTodayBuilder.medicationsToday([losartana], [], now);

      expect(result.single.status, DoseStatus.late);
      expect(result.single.nextTime, '08:00');
    });

    test('várias doses: 1 de 3 às 12:40 com 2 horários passados está atrasada',
        () {
      final result = CareTodayBuilder.medicationsToday(
        [levodopa],
        [dose('1', 'med-lev', DateTime(2026, 10, 7, 6, 5))],
        now,
      );

      expect(result.single.takenCount, 1);
      expect(result.single.status, DoseStatus.late);
      expect(result.single.nextTime, '12:00');
    });

    test('em dia: tomou as que já passaram e a próxima ainda não chegou', () {
      final result = CareTodayBuilder.medicationsToday(
        [levodopa],
        [
          dose('1', 'med-lev', DateTime(2026, 10, 7, 6, 5)),
          dose('2', 'med-lev', DateTime(2026, 10, 7, 12, 10)),
        ],
        now,
      );

      expect(result.single.status, DoseStatus.onTrack);
      expect(result.single.nextTime, '18:00');
    });

    test('dose de ontem não conta para hoje', () {
      final result = CareTodayBuilder.medicationsToday(
        [losartana],
        [dose('1', 'med-los', DateTime(2026, 10, 6, 8, 2))],
        now,
      );

      expect(result.single.takenCount, 0);
      expect(result.single.status, DoseStatus.late);
    });

    test('confirmações em excesso não passam do número de doses do dia', () {
      final result = CareTodayBuilder.medicationsToday(
        [losartana],
        [
          dose('1', 'med-los', DateTime(2026, 10, 7, 9)),
          dose('2', 'med-los', DateTime(2026, 10, 7, 10)),
        ],
        now,
      );

      expect(result.single.takenCount, 1);
    });

    test('repetir a fala não fecha o dia: 08:05 e 09:30 cobrem só o horário das '
        '08:00, e às 21:00 a dose das 20:00 está atrasada', () {
      const metformina = Medication(
        id: 'med-met',
        homeId: 'h',
        name: 'Metformina',
        times: ['08:00', '20:00'],
      );
      final result = CareTodayBuilder.medicationsToday(
        [metformina],
        [
          dose('1', 'med-met', DateTime(2026, 10, 7, 8, 5)),
          dose('2', 'med-met', DateTime(2026, 10, 7, 9, 30)),
        ],
        DateTime(2026, 10, 7, 21),
      );

      expect(result.single.takenCount, 1);
      expect(result.single.status, DoseStatus.late);
      expect(result.single.nextTime, '20:00');
    });

    test('dose tomada cedo cobre o horário mais próximo (11:50 é a das 12:00)',
        () {
      final result = CareTodayBuilder.medicationsToday(
        [levodopa],
        [
          dose('1', 'med-lev', DateTime(2026, 10, 7, 6, 5)),
          dose('2', 'med-lev', DateTime(2026, 10, 7, 11, 50)),
        ],
        now,
      );

      expect(result.single.takenCount, 2);
      expect(result.single.status, DoseStatus.onTrack);
      expect(result.single.nextTime, '18:00');
    });

    test('folga de 30 min: no horário em ponto ainda não é atraso', () {
      final noPonto = CareTodayBuilder.medicationsToday(
          [losartana], [], DateTime(2026, 10, 7, 8, 10));
      final passouDaFolga = CareTodayBuilder.medicationsToday(
          [losartana], [], DateTime(2026, 10, 7, 8, 30));

      expect(noPonto.single.status, DoseStatus.onTrack);
      expect(noPonto.single.nextTime, '08:00');
      expect(passouDaFolga.single.status, DoseStatus.late);
    });

    test('horário legado ("8h") não é horário de dose: vira "quando necessário"',
        () {
      final result = CareTodayBuilder.medicationsToday(
        [const Medication(id: 'x', homeId: 'h', name: 'Legado', times: ['8h'])],
        [],
        now,
      );

      expect(result.single.status, DoseStatus.asNeeded);
    });

    test('"não tomei" depois da última confirmação marca recusa; confirmar '
        'depois limpa', () {
      final recusou = CareTodayBuilder.medicationsToday(
        [losartana],
        [dose('1', 'med-los', DateTime(2026, 10, 7, 9), taken: false)],
        now,
      );
      final tomouDepois = CareTodayBuilder.medicationsToday(
        [losartana],
        [
          dose('1', 'med-los', DateTime(2026, 10, 7, 9), taken: false),
          dose('2', 'med-los', DateTime(2026, 10, 7, 10)),
        ],
        now,
      );

      expect(recusou.single.declinedToday, isTrue);
      expect(tomouDepois.single.declinedToday, isFalse);
    });

    test('sem horário fixo é "se necessário"; remédio inativo some', () {
      final result =
          CareTodayBuilder.medicationsToday([prn, inactive], [], now);

      expect(result, hasLength(1));
      expect(result.single.status, DoseStatus.asNeeded);
    });
  });

  group('timeline', () {
    test('traduz dose, sintoma com local e SOS, do mais novo ao mais antigo',
        () {
      final items = CareTodayBuilder.timeline(
        [
          event('a', 'near_fall', DateTime(2026, 10, 7, 12, 20),
              place: 'bathroom'),
          dose('b', 'med-los', DateTime(2026, 10, 7, 12, 34)),
          CareSignal(
            id: 'c',
            type: 'mobility',
            source: 'usage',
            value: const {'event': 'sos', 'channel': 'voice'},
            capturedAt: DateTime(2026, 10, 7, 12, 38),
          ),
        ],
        [losartana],
        patientFirstName: 'Maria',
      );

      expect(items.map((i) => i.title), [
        'Maria pediu ajuda (SOS)',
        'Maria confirmou Losartana',
        'Maria relatou uma quase-queda no banheiro',
      ]);
      expect(items.map((i) => i.source), [
        ActivitySource.voice,
        ActivitySource.voice,
        ActivitySource.voice,
      ]);
      expect(items.map((i) => i.concerning), [true, false, true]);
    });

    test('origem do toque aparece como "no app"', () {
      final items = CareTodayBuilder.timeline(
        [dose('1', 'med-los', DateTime(2026, 10, 7, 9), source: 'self_report')],
        [losartana],
        patientFirstName: 'Maria',
      );

      expect(items.single.source, ActivitySource.app);
      expect(items.single.source.label, 'no app');
    });

    test('dose negada vira "disse que não tomou" e pede atenção', () {
      final items = CareTodayBuilder.timeline(
        [dose('1', 'med-los', DateTime(2026, 10, 7, 9), taken: false)],
        [losartana],
        patientFirstName: 'Maria',
      );

      expect(items.single.title, 'Maria disse que não tomou Losartana');
      expect(items.single.concerning, isTrue);
    });

    test('evento e local desconhecidos aparecem legíveis, nunca crus', () {
      final items = CareTodayBuilder.timeline(
        [event('1', 'strange_thing', DateTime(2026, 10, 7, 9), place: 'garage')],
        [],
        patientFirstName: 'Maria',
      );

      expect(items.single.title, 'Maria relatou strange thing em garage');
    });

    test('leitura do relógio fica de fora e o limite vale', () {
      final items = CareTodayBuilder.timeline(
        [
          CareSignal(
            id: 'w',
            type: 'vitals',
            source: 'wearable',
            value: const {'steps': 1800},
            capturedAt: DateTime(2026, 10, 7, 12),
          ),
          for (var i = 0; i < 10; i++)
            dose('d$i', 'med-los', DateTime(2026, 10, 7, 8, i)),
        ],
        [losartana],
        patientFirstName: 'Maria',
        limit: 4,
      );

      expect(items, hasLength(4));
      expect(items.any((i) => i.id == 'w'), isFalse);
    });

    test('remédio que não está na lista não derruba a linha do tempo', () {
      final items = CareTodayBuilder.timeline(
        [dose('1', 'desconhecido', DateTime(2026, 10, 7, 9))],
        [],
        patientFirstName: 'Maria',
      );

      expect(items.single.title, 'Maria confirmou um remédio');
    });
  });
}
