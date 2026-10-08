import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/errors/result.dart';
import '../../../sos/domain/entities/emergency.dart';
import '../../../sos/presentation/open_sos_panel.dart';
import '../../data/voice_tools/voice_sos_gateway.dart';
import '../bloc/home_bloc.dart';
import '../widgets/home_body.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HomeBloc>()..add(const HomeInitEvent()),
      child: const _VoiceSosListener(child: HomeBody()),
    );
  }
}

/// Sobe a folha de SOS quando o agente de voz pede socorro (`trigger_sos`).
///
/// Sem isto o servidor abriria a janela de cancelamento e a Maria não veria
/// botão nenhum para cancelar.
class _VoiceSosListener extends StatefulWidget {
  const _VoiceSosListener({required this.child});

  final Widget child;

  @override
  State<_VoiceSosListener> createState() => _VoiceSosListenerState();
}

class _VoiceSosListenerState extends State<_VoiceSosListener> {
  StreamSubscription<void>? _subscription;

  /// Já há uma folha subindo por voz: dois pedidos seguidos não empilham.
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    final gateway = sl<VoiceSosGateway>();
    _subscription = gateway.requests.listen(_show);
    // Um pedido feito enquanto esta tela não estava na árvore não se perde.
    final pending = gateway.takePending();
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _show(pending));
    }
  }

  Future<void> _show(Result<EmergencyTicket> outcome) async {
    if (!mounted || _opening) return;
    _opening = true;
    try {
      await openSosPanel(
        context,
        channel: EmergencyChannel.voice,
        outcome: outcome,
      );
    } finally {
      _opening = false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
