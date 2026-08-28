import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:aura/core/di/service_locator.dart';
import 'package:aura/core/theme/app_colors.dart';
import 'package:aura/core/theme/app_dimensions.dart';

import '../../domain/entities/emergency.dart';
import '../bloc/sos_bloc.dart';
import '../sos_copy.dart';
import 'sos_panel.dart';

/// Como a tela consegue um bloc de SOS. O padrão é o injetor; o teste passa o
/// seu para poder afirmar quantas emergências o toque criou.
typedef SosBlocFactory = SosBloc Function();

/// Botão de socorro persistente (correção C3).
///
/// Mora em dois lugares e não depende de nenhum dos dois: na tela de voz da
/// Maria, ancorado no alto — com o teclado aberto quem encolhe é o rodapé, e
/// ali o botão nunca fica coberto nem empurrado — e na tela de abertura, porque
/// **o SOS não fica atrás de login** (regra 3).
///
/// Não pede bloc ao contexto: ele nasce no toque e morre quando a folha fecha.
/// É o que permite ao botão existir em telas que não sabem nada de emergência.
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    this.blocFactory,
    this.channel = EmergencyChannel.touch,
  });

  final SosBlocFactory? blocFactory;

  /// Como o socorro foi pedido. Toque, por aqui; a voz entra pelo agente.
  final EmergencyChannel channel;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> {
  /// Uma folha já está subindo.
  ///
  /// Toque dobrado, com Parkinson, é a regra e não a exceção. Hoje o segundo
  /// toque também morre na rota que o primeiro empilhou — mas depender disso
  /// seria depender de um efeito colateral do framework numa propriedade de
  /// segurança do paciente. Campo simples de propósito: vale já no mesmo gesto,
  /// antes de qualquer quadro. A trava que segura o resto está no bloc, que não
  /// depende de tela nenhuma.
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;

    final navigator = Navigator.of(context);
    final bloc = (widget.blocFactory ?? _fromInjector)()
      ..add(SosRequested(channel: widget.channel));

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
      // Fechar a folha não cancela nada: o disparo é do servidor. O que morre
      // aqui é o acompanhamento deste aparelho.
      await bloc.close();
      _opening = false;
    }
  }

  static SosBloc _fromInjector() => sl<SosBloc>();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: SosCopy.buttonSemantics,
      child: SizedBox.square(
        dimension: AppDimensions.sosButtonSize,
        child: Material(
          color: AppColors.error,
          shape: const CircleBorder(
            // Anel claro: o botão precisa se separar do fundo mesmo com o
            // brilho no mínimo ou com sol na tela.
            side: BorderSide(color: Colors.white, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _open,
            child: Center(
              child: ExcludeSemantics(
                child: Text(
                  SosCopy.buttonLabel,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
