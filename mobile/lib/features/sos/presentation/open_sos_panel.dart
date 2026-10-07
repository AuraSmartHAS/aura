import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:aura/core/di/service_locator.dart';
import 'package:aura/core/errors/result.dart';

import '../domain/entities/emergency.dart';
import 'bloc/sos_bloc.dart';
import 'widgets/sos_panel.dart';

/// Como a tela consegue um bloc de SOS. O padrão é o injetor; o teste passa o
/// seu para poder afirmar quantas emergências o toque criou.
typedef SosBlocFactory = SosBloc Function();

/// Abre a folha de SOS e registra o pedido. O bloc nasce aqui e morre quando a
/// folha fecha; fechar não cancela nada, porque o disparo é do servidor.
///
/// Quem chama guarda o próprio "já estou abrindo" (o botão e o ouvinte da voz).
/// Se as duas folhas coincidirem, o servidor devolve a mesma emergência.
///
/// Com [outcome] o pedido JÁ foi feito (pelo agente de voz): a folha só mostra o desfecho e não
/// chama o servidor de novo. Sem ele, a folha registra o pedido ao abrir (toque no botão).
Future<void> openSosPanel(
  BuildContext context, {
  SosBlocFactory? blocFactory,
  EmergencyChannel channel = EmergencyChannel.touch,
  Result<EmergencyTicket>? outcome,
}) async {
  final navigator = Navigator.of(context);
  final bloc = (blocFactory ?? () => sl<SosBloc>())()
    ..add(outcome == null
        ? SosRequested(channel: channel)
        : SosOutcomeAttached(outcome));

  try {
    await navigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => BlocProvider<SosBloc>.value(
          value: bloc,
          child: const SosPanel(),
        ),
      ),
    );
  } finally {
    await bloc.close();
  }
}
