import 'package:aura/features/sos/data/models/emergency_mapper.dart';
import 'package:aura/features/sos/domain/entities/emergency.dart';
import 'package:flutter_test/flutter_test.dart';

/// Correção C3 — a fronteira onde o JSON vira promessa.
///
/// A regra do mapeamento é uma só: **campo ausente nunca vira promessa.** Um
/// servidor antigo, um proxy que corta campo ou um erro de digitação no JSON
/// têm de degradar a tela para a ligação — nunca para o anúncio de que a Ana
/// foi avisada.
void main() {
  group('o que falta no JSON degrada, não promete', () {
    test('sem canPromiseAlert, a tela não pode prometer', () {
      final ticket = EmergencyMapper.ticketFromJson(const {
        'emergencyId': 'e-1',
        'state': 'dispatched',
      });

      expect(ticket.canPromiseAlert, isFalse);
      expect(ticket.transportReal, isFalse);
      expect(ticket.simulated, isTrue);
      // Janela do contrato, para a contagem não nascer zerada.
      expect(ticket.cancelWindowSeconds, 5);
    });

    test('estado desconhecido não é tratado como sucesso', () {
      final status = EmergencyMapper.statusFromJson(const {
        'emergencyId': 'e-1',
        'state': 'algo_que_ainda_nao_existe',
        'canPromiseAlert': true,
      });

      expect(status.state, EmergencyState.unknown);
    });

    test('cancelamento sem alertSent assume que o aviso saiu', () {
      final cancellation = EmergencyMapper.cancellationFromJson(const {
        'emergencyId': 'e-1',
        'state': 'cancelled',
      });

      // "Não avisei ninguém" é a única frase que dói se estiver errada.
      expect(cancellation.alertSent, isTrue);
      expect(cancellation.withinWindow, isFalse);
    });
  });

  group('o que o contrato manda é lido inteiro', () {
    test('o disparo traz estado, janela, contato e a frase do servidor', () {
      final ticket = EmergencyMapper.ticketFromJson(const {
        'emergencyId': 'e-1',
        'homeId': 'casa-1',
        'state': 'waiting_cancel',
        'dispatchAt': '2026-08-27T17:32:05Z',
        'cancelWindowSeconds': 5,
        'escalateAfterSeconds': 60,
        'transportReal': false,
        'simulated': true,
        'recipientCount': 1,
        'primaryContactName': 'Ana',
        'throttled': false,
        'deduplicated': false,
        'canPromiseAlert': false,
        'degradedReason': 'simulated_transport',
        'spokenMessage': 'Não consigo avisar a Ana daqui.',
      });

      expect(ticket.id, 'e-1');
      expect(ticket.state, EmergencyState.waitingCancel);
      expect(ticket.cancelWindowSeconds, 5);
      expect(ticket.escalateAfterSeconds, 60);
      expect(ticket.primaryContactName, 'Ana');
      expect(ticket.canPromiseAlert, isFalse);
      expect(ticket.degradedReason, DegradedReason.simulatedTransport);
      expect(ticket.spokenMessage, 'Não consigo avisar a Ana daqui.');
    });

    test('os três motivos de degradação do contrato são reconhecidos', () {
      expect(
        DegradedReason.fromWire('simulated_transport'),
        DegradedReason.simulatedTransport,
      );
      expect(
        DegradedReason.fromWire('no_registered_device'),
        DegradedReason.noRegisteredDevice,
      );
      expect(DegradedReason.fromWire('throttled'), DegradedReason.throttled);
      // Motivo novo continua sendo motivo: degrada, não some.
      expect(DegradedReason.fromWire('algo_novo'), DegradedReason.unknown);
      expect(DegradedReason.fromWire(null), isNull);
    });

    test('a hora do aviso vem no fuso de quem lê a tela', () {
      final status = EmergencyMapper.statusFromJson(const {
        'emergencyId': 'e-1',
        'state': 'dispatched',
        'dispatchedAt': '2026-08-27T17:32:05Z',
        'canPromiseAlert': true,
      });

      expect(status.dispatchedAt, isNotNull);
      expect(status.dispatchedAt!.isUtc, isFalse);
      expect(
        status.dispatchedAt,
        DateTime.utc(2026, 8, 27, 17, 32, 5).toLocal(),
      );
    });
  });
}
