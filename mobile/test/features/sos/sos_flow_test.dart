import 'dart:async';

import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/platform/phone_dialer.dart';
import 'package:aura/features/home/presentation/home_error_copy.dart';
import 'package:aura/features/sos/domain/entities/emergency.dart';
import 'package:aura/features/sos/domain/repositories/emergency_repository.dart';
import 'package:aura/features/sos/domain/usecases/cancel_emergency_usecase.dart';
import 'package:aura/features/sos/domain/usecases/get_emergency_status_usecase.dart';
import 'package:aura/features/sos/domain/usecases/trigger_emergency_usecase.dart';
import 'package:aura/features/sos/presentation/bloc/sos_bloc.dart';
import 'package:aura/features/sos/presentation/sos_copy.dart';
import 'package:aura/features/sos/presentation/widgets/sos_button.dart';
import 'package:aura/features/sos/presentation/widgets/sos_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Correção C3 — SOS e fluxo de crise.
///
/// Estes testes existem porque a versão 1 do plano produzia o pior artefato
/// possível: botão vermelho gigante, voz dizendo "avisei a Ana" e nenhuma
/// notificação saindo do aparelho. O contrato foi desenhado para impedir isso —
/// `canPromiseAlert` e `spokenMessage` — e o que se verifica aqui é que a tela
/// obedece.
void main() {
  group('regra 1 — a tela nunca promete o que o sistema não sabe', () {
    test(
        'canPromiseAlert falso: nada de "avisei", e a tela cai para a ligação',
        () async {
      final repository = _FakeEmergencyRepository(
        ticket: _ticket(
          state: EmergencyState.waitingCancel,
          canPromiseAlert: false,
          degradedReason: DegradedReason.simulatedTransport,
          spokenMessage:
              'Não consigo avisar a Ana daqui. Toque no botão grande para '
              'ligar para ela.',
        ),
      );
      final bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const SosRequested());
      await _tick();

      // O registro aconteceu — o pedido existe no servidor.
      expect(repository.triggerCalls, hasLength(1));

      // Mas a tela não anuncia entrega nenhuma.
      expect(bloc.state.phase, SosPhase.failed);
      expect(bloc.state.offersCallInstead, isTrue);
      expect(bloc.state.canPromiseAlert, isFalse);
      expect(bloc.state.degradedReason, DegradedReason.simulatedTransport);

      // E a frase é a do servidor, palavra por palavra.
      expect(bloc.state.spokenMessage, repository.ticket!.spokenMessage);
      _semPromessaDeAviso(bloc.state.spokenMessage!);
    });

    test(
        'nem "dispatched" vira "entregue" quando o aviso não pode ser prometido',
        () async {
      final repository = _FakeEmergencyRepository(
        ticket: _ticket(
          state: EmergencyState.dispatched,
          canPromiseAlert: false,
          degradedReason: DegradedReason.noRegisteredDevice,
          spokenMessage: null,
        ),
      );
      final bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const SosRequested());
      await _tick();

      // O estado do servidor diz "disparado"; sem poder prometer, a tela
      // continua sendo a da falha. É aqui que a regra 1 vive ou morre.
      expect(bloc.state.phase, SosPhase.failed);
      expect(bloc.state.spokenMessage, SosCopy.failed('Ana'));
      _semPromessaDeAviso(bloc.state.spokenMessage!);
    });

    test('os três motivos de degradação têm explicação própria', () async {
      const motivos = [
        DegradedReason.simulatedTransport,
        DegradedReason.noRegisteredDevice,
        DegradedReason.throttled,
      ];

      final frases = <String>{};
      for (final motivo in motivos) {
        final repository = _FakeEmergencyRepository(
          ticket: _ticket(
            state: EmergencyState.waitingCancel,
            canPromiseAlert: false,
            degradedReason: motivo,
            spokenMessage: null,
          ),
        );
        final bloc = _buildBloc(repository);

        bloc.add(const SosRequested());
        await _tick();

        expect(bloc.state.degradedReason, motivo);
        // Todos os três levam ao mesmo lugar: a ligação.
        expect(bloc.state.offersCallInstead, isTrue);

        final explicacao = SosCopy.degradedReason(motivo, 'Ana');
        expect(explicacao, isNotEmpty);
        _semPromessaDeAviso(explicacao);
        frases.add(explicacao);

        await bloc.close();
      }

      // Três motivos, três explicações diferentes — senão a Maria não fica
      // sabendo qual é o caso dela.
      expect(frases, hasLength(3));
    });

    testWidgets(
        'canPromiseAlert falso: o botão muda de texto e de função, e o toque '
        'abre o discador', (tester) async {
      final repository = _FakeEmergencyRepository(
        ticket: _ticket(
          state: EmergencyState.waitingCancel,
          canPromiseAlert: false,
          degradedReason: DegradedReason.simulatedTransport,
          spokenMessage: null,
        ),
      );
      final dialer = _FakeDialer();
      final bloc = _buildBloc(repository, dialer: dialer);

      await _pumpPanel(tester, bloc);
      bloc.add(const SosRequested());
      await _settle(tester);

      // A tela **não** diz que avisou.
      expect(find.text(SosCopy.failed('Ana')), findsOneWidget);
      expect(find.text(SosCopy.delivered('Ana', null)), findsNothing);
      expect(find.text(SosCopy.cancelWhileCounting), findsNothing);

      // O botão principal virou a ligação, com o texto da regra 1.
      final ligar = find.text(SosCopy.cannotAlertAction('Ana'));
      expect(ligar, findsOneWidget);

      await tester.tap(ligar);
      await _settle(tester);
      expect(dialer.dialed, [_kContactPhone]);

      await _stop(tester, bloc);
    });
  });

  group('regra 2 — a contagem na tela é só feedback', () {
    testWidgets('o toque registra a emergência e mostra a contagem',
        (tester) async {
      final repository = _FakeEmergencyRepository(ticket: _ticket());
      final bloc = _buildBloc(repository);

      await _pumpButton(tester, bloc);
      await tester.tap(find.byType(SosButton));
      await _settle(tester);

      // Registrou na hora, antes de qualquer contagem.
      expect(repository.triggerCalls, [EmergencyChannel.touch]);

      expect(bloc.state.phase, SosPhase.counting);
      expect(find.text('5'), findsOneWidget);
      expect(find.text(SosCopy.countdown(5)), findsOneWidget);
      // E está escrito na tela que o disparo não depende deste aparelho.
      expect(find.text(SosCopy.dispatchIsServerSide), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('4'), findsOneWidget);

      await _stop(tester, bloc);
    });

    test('a contagem chegando a zero não muda a fase — quem dispara é o '
        'servidor', () async {
      final repository = _FakeEmergencyRepository(ticket: _ticket());
      // Sem nenhuma resposta nova do servidor, a tela não pode evoluir sozinha.
      final bloc = _buildBloc(repository, poll: const Duration(days: 1));
      addTearDown(bloc.close);

      bloc.add(const SosRequested());
      await _tick();
      expect(bloc.state.phase, SosPhase.counting);

      for (var i = 0; i < 8; i++) {
        bloc.add(const SosCountdownTicked());
        await _tick();
      }

      expect(bloc.state.secondsRemaining, 0);
      // Zero na tela e nada mais: o "entregue" só chega pelo acompanhamento.
      expect(bloc.state.phase, SosPhase.counting);
    });
  });

  group('regra 3 — o socorro não depende de sessão', () {
    test('aparelho que não sabe a casa não promete aviso: oferece ligação',
        () async {
      final repository = _FakeEmergencyRepository(
        triggerFailure: const DeviceNotPairedFailure(),
      );
      final bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const SosRequested());
      await _tick();

      expect(bloc.state.phase, SosPhase.failed);
      expect(bloc.state.spokenMessage, SosCopy.noPairedHome);
      _semPromessaDeAviso(bloc.state.spokenMessage!);
    });
  });

  group('regra 4 — os quatro estados falados', () {
    test('os quatro estados do servidor viram as quatro falas certas',
        () async {
      // 1/4 — enviando.
      final repository = _FakeEmergencyRepository(
        ticket: _ticket(spokenMessage: 'Estou avisando a Ana.'),
      );
      final bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const SosRequested());
      await _tick();
      expect(bloc.state.phase, SosPhase.counting);
      expect(bloc.state.spokenMessage, 'Estou avisando a Ana.');

      // 2/4 — entregue, com a hora, vinda do acompanhamento.
      repository.nextStatus = _status(
        state: EmergencyState.dispatched,
        dispatchedAt: DateTime(2026, 8, 27, 14, 32),
        spokenMessage:
            'Pronto. O aviso chegou no celular da Ana às 14h32. Fico aqui '
            'com você.',
      );
      bloc.add(const SosStatusPolled());
      await _tick();
      expect(bloc.state.phase, SosPhase.delivered);
      expect(bloc.state.spokenMessage, contains('14h32'));

      // 3/4 — confirmado pela cuidadora.
      repository.nextStatus = _status(
        state: EmergencyState.acknowledged,
        acknowledgedByName: 'Ana',
        spokenMessage: 'A Ana viu e disse que está indo.',
      );
      bloc.add(const SosStatusPolled());
      await _tick();
      expect(bloc.state.phase, SosPhase.acknowledged);
      expect(bloc.state.spokenMessage, 'A Ana viu e disse que está indo.');

      // 4/4 — falha. O servidor deixou de poder prometer o aviso.
      repository.nextStatus = _status(
        state: EmergencyState.dispatched,
        canPromiseAlert: false,
        degradedReason: DegradedReason.noRegisteredDevice,
        spokenMessage:
            'Não consegui avisar a Ana. Toque no botão grande para ligar '
            'para ela.',
      );
      bloc.add(const SosStatusPolled());
      await _tick();
      expect(bloc.state.phase, SosPhase.failed);
      expect(bloc.state.spokenMessage, startsWith('Não consegui avisar a Ana'));
    });

    test('sem frase do servidor, a fala local diz o mesmo sem prometer mais',
        () async {
      final repository = _FakeEmergencyRepository(
        ticket: _ticket(spokenMessage: null),
      );
      final bloc = _buildBloc(repository, poll: const Duration(days: 1));
      addTearDown(bloc.close);

      bloc.add(const SosRequested());
      await _tick();
      expect(bloc.state.spokenMessage, SosCopy.sending('Ana'));

      final quando = DateTime(2026, 8, 27, 14, 32);
      repository.nextStatus = _status(
        state: EmergencyState.dispatched,
        dispatchedAt: quando,
        spokenMessage: null,
      );
      bloc.add(const SosStatusPolled());
      await _tick();
      expect(bloc.state.spokenMessage, SosCopy.delivered('Ana', quando));
      // "Saiu", não "chegou": o servidor confirma o disparo, não a leitura.
      expect(bloc.state.spokenMessage, contains('14h32'));

      repository.nextStatus = _status(
        state: EmergencyState.acknowledged,
        acknowledgedByName: 'Ana',
        spokenMessage: null,
      );
      bloc.add(const SosStatusPolled());
      await _tick();
      expect(bloc.state.spokenMessage, SosCopy.acknowledged('Ana'));
    });

    test('nenhuma fala do dicionário promete central 24h ou ajuda a caminho',
        () async {
      final frases = <String>[
        SosCopy.sending('Ana'),
        SosCopy.sending(null),
        SosCopy.delivered('Ana', DateTime(2026, 8, 27, 14, 32)),
        SosCopy.delivered(null, null),
        SosCopy.acknowledged('Ana'),
        SosCopy.acknowledged(null),
        SosCopy.failed('Ana'),
        SosCopy.failed(null),
        SosCopy.cancelled(withinWindow: true, alertSent: false, contactName: 'Ana'),
        SosCopy.cancelled(withinWindow: false, alertSent: true, contactName: 'Ana'),
        SosCopy.scopeDisclaimer,
        SosCopy.dispatchIsServerSide,
        SosCopy.noPairedHome,
        for (final motivo in DegradedReason.values)
          SosCopy.degradedReason(motivo, 'Ana'),
      ];

      for (final frase in frases) {
        _semPromessaDeSocorro(frase);
      }
    });
  });

  group('acompanhamento por polling', () {
    // Não há push para a Maria: o estado só chega se a tela perguntar.
    test('o laço leva o estado do servidor até a tela e para quando acaba',
        () async {
      final repository = _FakeEmergencyRepository(ticket: _ticket());
      final bloc = _buildBloc(repository, poll: const Duration(milliseconds: 30));
      addTearDown(bloc.close);

      bloc.add(const SosRequested());
      await _tick();
      expect(bloc.state.phase, SosPhase.counting);

      repository.nextStatus = _status(
        state: EmergencyState.dispatched,
        dispatchedAt: DateTime(2026, 8, 27, 14, 32),
        spokenMessage: 'Pronto. O aviso saiu para a Ana às 14h32.',
      );
      await _waitFor(() => bloc.state.phase == SosPhase.delivered);
      expect(repository.statusCalls, isNotEmpty);

      repository.nextStatus = _status(
        state: EmergencyState.acknowledged,
        acknowledgedByName: 'Ana',
        spokenMessage: 'A Ana viu e disse que está indo.',
      );
      await _waitFor(() => bloc.state.phase == SosPhase.acknowledged);

      // Confirmado é o fim: não há mais o que perguntar ao servidor.
      final chamadas = repository.statusCalls.length;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(repository.statusCalls, hasLength(chamadas));
    });

    test('um acompanhamento que falha não desmente o que já se sabe', () async {
      final repository = _FakeEmergencyRepository(ticket: _ticket());
      final bloc = _buildBloc(repository, poll: const Duration(milliseconds: 30));
      addTearDown(bloc.close);

      bloc.add(const SosRequested());
      await _tick();

      repository.nextStatus = _status(
        state: EmergencyState.dispatched,
        dispatchedAt: DateTime(2026, 8, 27, 14, 32),
        spokenMessage: 'Pronto. O aviso saiu para a Ana às 14h32.',
      );
      await _waitFor(() => bloc.state.phase == SosPhase.delivered);

      // O servidor para de responder (modo avião, sinal que sumiu).
      final falaConhecida = bloc.state.spokenMessage;
      repository.nextStatus = null;
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(bloc.state.phase, SosPhase.delivered);
      expect(bloc.state.spokenMessage, falaConhecida);
    });
  });

  group('cancelamento', () {
    testWidgets('cancelar dentro da janela chama a rota de cancelamento',
        (tester) async {
      final repository = _FakeEmergencyRepository(
        ticket: _ticket(),
        cancellation: _cancellation(withinWindow: true, alertSent: false),
      );
      final bloc = _buildBloc(repository);

      await _pumpButton(tester, bloc);
      await tester.tap(find.byType(SosButton));
      await _settle(tester);

      final cancelar = find.text(SosCopy.cancelWhileCounting);
      expect(cancelar, findsOneWidget);
      // Alvo grande e óbvio: nada de link de texto para desfazer um socorro.
      expect(tester.getSize(cancelar).height, greaterThan(0));

      await tester.tap(cancelar);
      await _settle(tester);

      expect(repository.cancelCalls, [_kEmergencyId]);
      expect(bloc.state.phase, SosPhase.cancelled);
      expect(find.text(SosCopy.close), findsOneWidget);

      await _stop(tester, bloc);
    });

    test('fora da janela, a tela não diz que o aviso deixou de sair', () async {
      final repository = _FakeEmergencyRepository(
        ticket: _ticket(),
        cancellation: _cancellation(
          withinWindow: false,
          alertSent: true,
          spokenMessage: null,
        ),
      );
      final bloc = _buildBloc(repository, poll: const Duration(days: 1));
      addTearDown(bloc.close);

      bloc.add(const SosRequested());
      await _tick();
      bloc.add(const SosCancelRequested());
      await _tick();

      expect(bloc.state.phase, SosPhase.cancelled);
      expect(bloc.state.alertSent, isTrue);
      expect(bloc.state.spokenMessage, contains('já tinha saído'));
    });

    test('cancelamento que não chega ao servidor não vira "cancelado"',
        () async {
      final repository = _FakeEmergencyRepository(
        ticket: _ticket(),
        cancelFailure: const AppFailure.networkError(message: 'sem conexão'),
      );
      final bloc = _buildBloc(repository, poll: const Duration(days: 1));
      addTearDown(bloc.close);

      bloc.add(const SosRequested());
      await _tick();
      bloc.add(const SosCancelRequested());
      await _tick();

      // O pedido continua de pé no servidor — dizer "cancelado" aqui seria a
      // mentira mais cara da tela.
      expect(bloc.state.phase, isNot(SosPhase.cancelled));
      expect(bloc.state.errorMessage, HomeErrorCopy.of(HomeErrorCode.sosOffline));
    });
  });

  group('toque acidental', () {
    testWidgets('toque duplo rápido não cria duas emergências', (tester) async {
      final repository = _FakeEmergencyRepository(ticket: _ticket());
      var blocsCriados = 0;
      final bloc = _buildBloc(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosButton(
              blocFactory: () {
                blocsCriados++;
                return bloc;
              },
            ),
          ),
        ),
      );

      // Dois toques seguidos, sem quadro entre eles: é o tremor, não uma
      // segunda intenção.
      await tester.tap(find.byType(SosButton), warnIfMissed: false);
      await tester.tap(find.byType(SosButton), warnIfMissed: false);
      await _settle(tester);

      // Um bloc, uma emergência, uma folha aberta.
      expect(blocsCriados, 1);
      expect(repository.triggerCalls, hasLength(1));
      expect(find.byType(SosPanel), findsOneWidget);

      await _stop(tester, bloc);
    });

    test('dois pedidos no mesmo bloc viram uma chamada só', () async {
      // Esta é a trava que segura de verdade o toque dobrado: a do botão
      // depende de a folha já estar empilhada, e a do bloc não depende de nada.
      final repository = _FakeEmergencyRepository(ticket: _ticket());
      final bloc = _buildBloc(repository, poll: const Duration(days: 1));
      addTearDown(bloc.close);

      bloc.add(const SosRequested());
      bloc.add(const SosRequested());
      await _tick();
      bloc.add(const SosRequested());
      await _tick();

      expect(repository.triggerCalls, hasLength(1));
    });
  });

  group('erro humano em português', () {
    test('falha de rede no pedido usa o dicionário — nada de inglês nem de '
        'exceção crua', () async {
      final repository = _FakeEmergencyRepository(
        triggerFailure: const AppFailure.networkError(
          message: 'SocketException: Network is unreachable',
        ),
      );
      final bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const SosRequested());
      await _tick();

      expect(bloc.state.phase, SosPhase.failed);
      expect(
        bloc.state.errorMessage,
        HomeErrorCopy.of(HomeErrorCode.sosOffline),
      );
      expect(bloc.state.errorMessage, isNot(contains('Exception')));
    });

    test('falha sem cara de rede cai na frase do socorro, não na da conversa',
        () async {
      final repository = _FakeEmergencyRepository(
        triggerFailure: const AppFailure.unexpected(message: 'Erro interno.'),
      );
      final bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const SosRequested());
      await _tick();

      expect(
        bloc.state.errorMessage,
        HomeErrorCopy.of(HomeErrorCode.sosUnreachable),
      );
    });
  });

  group('pós-pedido', () {
    testWidgets('"Ligar 192" fica a um toque e abre o discador', (tester) async {
      final repository = _FakeEmergencyRepository(
        ticket: _ticket(
          state: EmergencyState.dispatched,
          spokenMessage: 'Pronto. O aviso saiu para a Ana às 14h32.',
        ),
      );
      final dialer = _FakeDialer();
      final bloc = _buildBloc(repository, dialer: dialer);

      await _pumpPanel(tester, bloc);
      bloc.add(const SosRequested());
      await _settle(tester);

      expect(bloc.state.phase, SosPhase.delivered);

      final ligar192 = find.text(SosCopy.callEmergency('192'));
      expect(ligar192, findsOneWidget);
      await tester.tap(ligar192);
      await _settle(tester);

      expect(dialer.dialed, ['192']);
      // Quem liga é uma pessoa: o app abriu o discador e parou ali.
      expect(find.text(SosCopy.callEmergencySubtitle), findsOneWidget);
      // E o guardrail do produto está escrito na tela.
      expect(find.text(SosCopy.scopeDisclaimer), findsOneWidget);

      await _stop(tester, bloc);
    });
  });
}

// ── Cenário ────────────────────────────────────────────────────────

const String _kEmergencyId = 'emergencia-1';
const String _kContactPhone = '11999990000';

EmergencyTicket _ticket({
  EmergencyState state = EmergencyState.waitingCancel,
  bool canPromiseAlert = true,
  DegradedReason? degradedReason,
  String? spokenMessage = 'Estou avisando a Ana.',
  bool deduplicated = false,
}) {
  return EmergencyTicket(
    id: _kEmergencyId,
    state: state,
    cancelWindowSeconds: 5,
    escalateAfterSeconds: 60,
    canPromiseAlert: canPromiseAlert,
    degradedReason: degradedReason,
    primaryContactName: 'Ana',
    recipientCount: canPromiseAlert ? 1 : 0,
    transportReal: canPromiseAlert,
    simulated: !canPromiseAlert,
    deduplicated: deduplicated,
    spokenMessage: spokenMessage,
  );
}

EmergencyStatus _status({
  required EmergencyState state,
  bool canPromiseAlert = true,
  DegradedReason? degradedReason,
  DateTime? dispatchedAt,
  String? acknowledgedByName,
  String? spokenMessage,
}) {
  return EmergencyStatus(
    id: _kEmergencyId,
    state: state,
    canPromiseAlert: canPromiseAlert,
    degradedReason: degradedReason,
    dispatchedAt: dispatchedAt,
    acknowledgedByName: acknowledgedByName,
    spokenMessage: spokenMessage,
  );
}

EmergencyCancellation _cancellation({
  required bool withinWindow,
  required bool alertSent,
  String? spokenMessage = 'Cancelado. Contei para a Ana que foi engano.',
}) {
  return EmergencyCancellation(
    id: _kEmergencyId,
    state: EmergencyState.cancelled,
    withinWindow: withinWindow,
    alertSent: alertSent,
    retractionSent: true,
    spokenMessage: spokenMessage,
  );
}

SosBloc _buildBloc(
  _FakeEmergencyRepository repository, {
  PhoneDialer? dialer,
  String contactPhone = _kContactPhone,
  Duration poll = const Duration(seconds: 2),
}) {
  return SosBloc(
    triggerEmergencyUseCase: TriggerEmergencyUseCase(repository),
    cancelEmergencyUseCase: CancelEmergencyUseCase(repository),
    getEmergencyStatusUseCase: GetEmergencyStatusUseCase(repository),
    phoneDialer: dialer ?? _FakeDialer(),
    emergencyPhone: '192',
    contactPhone: contactPhone,
    pollInterval: poll,
  );
}

// ── Asserções de honestidade ───────────────────────────────────────

/// Nenhuma variação de "avisei" pode aparecer numa frase que a tela diz quando
/// o servidor não pôde prometer o aviso.
void _semPromessaDeAviso(String frase) {
  const proibidos = ['avisei', 'aviso chegou', 'aviso saiu', 'já foi avisada'];
  final minuscula = frase.toLowerCase();
  for (final termo in proibidos) {
    expect(
      minuscula.contains(termo),
      isFalse,
      reason: 'promessa de aviso numa frase de degradação: "$frase"',
    );
  }
}

/// O AURA avisa uma pessoa. Não é central de emergência, e a cópia não pode
/// escorregar para isso — é o risco nomeado no plano.
void _semPromessaDeSocorro(String frase) {
  const proibidos = [
    'ajuda a caminho',
    'ajuda está a caminho',
    '24h',
    '24 horas',
    'central de atendimento',
    'socorro a caminho',
    'estamos indo',
    'já chamamos',
    'chamamos o samu',
    'ambulância',
  ];
  final minuscula = frase.toLowerCase();
  for (final termo in proibidos) {
    expect(
      minuscula.contains(termo),
      isFalse,
      reason: 'promessa de central de emergência na frase: "$frase"',
    );
  }
}

// ── Utilidades de tempo ────────────────────────────────────────────

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 20));

/// Espera uma condição virar verdade, com teto. Usado nos testes do laço de
/// acompanhamento, onde quem manda no tempo é um temporizador de verdade.
Future<void> _waitFor(bool Function() condition) async {
  final limite = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(limite)) {
    await _tick();
  }
  expect(condition(), isTrue, reason: 'a condição não chegou a valer');
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Encerra o bloc dentro do teste de widget.
///
/// `close()` não completa dentro do relógio falso do `testWidgets`, mas os
/// temporizadores morrem na primeira linha dele — que é o que precisa acontecer
/// antes de o teste terminar.
Future<void> _stop(WidgetTester tester, SosBloc bloc) async {
  unawaited(bloc.close());
  await tester.pump();
}

Future<void> _pumpPanel(WidgetTester tester, SosBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<SosBloc>.value(value: bloc, child: const SosPanel()),
    ),
  );
  await _settle(tester);
}

Future<void> _pumpButton(WidgetTester tester, SosBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SosButton(blocFactory: () => bloc)),
    ),
  );
  await _settle(tester);
}

// ── Dublês ─────────────────────────────────────────────────────────

/// Servidor de emergência de mentira, com o mesmo comportamento observável do
/// real: responde na hora ao registro e devolve o estado quando perguntado.
class _FakeEmergencyRepository implements EmergencyRepository {
  _FakeEmergencyRepository({
    this.ticket,
    this.triggerFailure,
    this.cancellation,
    this.cancelFailure,
  });

  final EmergencyTicket? ticket;
  final Object? triggerFailure;
  final EmergencyCancellation? cancellation;
  final Object? cancelFailure;

  /// Próxima resposta do acompanhamento. Nulo = o servidor não tem novidade.
  EmergencyStatus? nextStatus;

  final List<EmergencyChannel> triggerCalls = [];
  final List<String> cancelCalls = [];
  final List<String> statusCalls = [];

  @override
  Future<Result<EmergencyTicket>> trigger({
    required EmergencyChannel channel,
  }) async {
    triggerCalls.add(channel);
    if (triggerFailure != null) return Failure(triggerFailure);
    return Success(ticket!);
  }

  @override
  Future<Result<EmergencyCancellation>> cancel(String emergencyId) async {
    cancelCalls.add(emergencyId);
    if (cancelFailure != null) return Failure(cancelFailure);
    return Success(
      cancellation ?? _cancellation(withinWindow: true, alertSent: false),
    );
  }

  @override
  Future<Result<EmergencyStatus>> status(String emergencyId) async {
    statusCalls.add(emergencyId);
    final status = nextStatus;
    if (status == null) {
      return const Failure('sem novidade');
    }
    return Success(status);
  }
}

class _FakeDialer implements PhoneDialer {
  final List<String> dialed = [];
  bool succeed = true;

  @override
  Future<bool> openDialer(String phoneNumber) async {
    dialed.add(phoneNumber);
    return succeed;
  }
}
