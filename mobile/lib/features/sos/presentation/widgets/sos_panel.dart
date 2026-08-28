import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:aura/core/theme/app_colors.dart';
import 'package:aura/core/theme/app_dimensions.dart';

import '../bloc/sos_bloc.dart';
import '../sos_copy.dart';

/// A tela do pedido de ajuda: contagem, cancelamento e pós-pedido.
///
/// Ela mostra **uma frase grande** — a que o servidor mandou dizer — e no
/// máximo dois caminhos de ação por vez. Quem está usando isto acabou de cair
/// ou está com medo; lista de opções é o oposto do que serve.
class SosPanel extends StatelessWidget {
  const SosPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SosBloc, SosState>(
      builder: (context, state) {
        final phone = state.emergencyPhone;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text(SosCopy.panelTitle),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.lg,
                AppDimensions.lg,
                AppDimensions.lg,
                AppDimensions.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SpokenLine(
                    message: state.spokenMessage ?? '',
                    isTrouble: state.phase == SosPhase.failed,
                  ),
                  if (state.phase == SosPhase.counting) ...[
                    const SizedBox(height: AppDimensions.lg),
                    _Countdown(seconds: state.secondsRemaining),
                    const SizedBox(height: AppDimensions.md),
                    const _QuietNote(text: SosCopy.dispatchIsServerSide),
                  ],
                  if (state.degradedReason != null) ...[
                    const SizedBox(height: AppDimensions.md),
                    _QuietNote(
                      text: SosCopy.degradedReason(
                        state.degradedReason!,
                        state.contactName,
                      ),
                    ),
                  ],
                  if (state.deduplicated) ...[
                    const SizedBox(height: AppDimensions.md),
                    const _QuietNote(text: SosCopy.deduplicated),
                  ],
                  if (state.errorMessage != null &&
                      state.errorMessage != state.spokenMessage) ...[
                    const SizedBox(height: AppDimensions.md),
                    _TroubleNote(text: state.errorMessage!),
                  ],
                  if (state.dialerFailed) ...[
                    const SizedBox(height: AppDimensions.md),
                    _TroubleNote(
                      text: state.contactPhoneKnown
                          ? SosCopy.callNotOpened
                          : SosCopy.noContactPhone,
                    ),
                  ],
                  const SizedBox(height: AppDimensions.xl),
                  ..._actions(context, state, phone),
                  const SizedBox(height: AppDimensions.xl),
                  const _QuietNote(text: SosCopy.scopeDisclaimer),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// A ordem dos botões é a ordem do que serve agora.
  ///
  /// Enquanto a contagem corre, o que serve é desistir: "cancelar" ocupa o
  /// lugar de honra e o 192 fica em segundo plano. Quando o servidor diz que
  /// **não pode prometer o aviso**, o lugar de honra passa para a ligação — é o
  /// botão que "muda de função e de texto" da regra 1.
  List<Widget> _actions(BuildContext context, SosState state, String phone) {
    final bloc = context.read<SosBloc>();
    final widgets = <Widget>[];

    /// O pedido já se resolveu de algum jeito — é onde cabem "Fechar" e a
    /// ligação para o contato. Enquanto a contagem corre, cada botão a mais
    /// disputa atenção com o único que importa ali, que é cancelar.
    final resolvido = state.phase != SosPhase.counting &&
        state.phase != SosPhase.registering;

    if (state.offersCallInstead) {
      widgets.add(
        _BigAction(
          label: state.contactPhoneKnown
              ? SosCopy.cannotAlertAction(state.contactName)
              : SosCopy.callEmergency(phone),
          icon: Icons.phone_in_talk,
          background: AppColors.error,
          onPressed: () => bloc.add(
            SosCallRequested(
              state.contactPhoneKnown
                  ? SosCallTarget.contact
                  : SosCallTarget.emergencyService,
            ),
          ),
        ),
      );
    } else if (state.canCancel) {
      widgets.add(
        _BigAction(
          label: state.phase == SosPhase.counting
              ? SosCopy.cancelWhileCounting
              : SosCopy.cancelAfterDispatch,
          semanticsLabel: SosCopy.cancelSemantics,
          icon: Icons.close,
          // Verde de "estou bem": cancelar não é a ação perigosa da tela.
          background: AppColors.confirm,
          onPressed: state.isCancelling
              ? null
              : () => bloc.add(const SosCancelRequested()),
        ),
      );
    }

    // "Ligar 192" a um toque, em todo estado de pós-pedido — e disponível (mais
    // discreto) já durante a contagem. Quem liga é uma pessoa: o app só abre o
    // telefone com o número posto.
    if (!(state.offersCallInstead && !state.contactPhoneKnown)) {
      widgets
        ..add(const SizedBox(height: AppDimensions.md))
        ..add(
          _BigAction(
            label: SosCopy.callEmergency(phone),
            helper: SosCopy.callEmergencySubtitle,
            icon: Icons.local_hospital_outlined,
            background:
                state.phase == SosPhase.counting ? null : AppColors.error,
            onPressed: () =>
                bloc.add(const SosCallRequested(SosCallTarget.emergencyService)),
          ),
        );
    }

    if (state.contactPhoneKnown && !state.offersCallInstead && resolvido) {
      widgets
        ..add(const SizedBox(height: AppDimensions.md))
        ..add(
          _BigAction(
            label: SosCopy.callContact(state.contactName),
            icon: Icons.phone_outlined,
            onPressed: () =>
                bloc.add(const SosCallRequested(SosCallTarget.contact)),
          ),
        );
    }

    // Fechar só depois que há o que fechar: durante a contagem, sair da tela
    // não resolve nada e tira a Maria de onde está o botão de cancelar.
    if (resolvido) {
      widgets
        ..add(const SizedBox(height: AppDimensions.md))
        ..add(
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text(SosCopy.close),
          ),
        );
    }

    return widgets;
  }
}

/// A frase da vez, grande e anunciada.
///
/// Os quatro estados são "falados": o app não tem voz própria, então o canal de
/// áudio disponível é o leitor de tela — o mesmo caminho que os chips de
/// intenção já usam. Cada frase nova é anunciada uma vez.
class _SpokenLine extends StatefulWidget {
  const _SpokenLine({required this.message, required this.isTrouble});

  final String message;
  final bool isTrouble;

  @override
  State<_SpokenLine> createState() => _SpokenLineState();
}

class _SpokenLineState extends State<_SpokenLine> {
  @override
  void initState() {
    super.initState();
    _announce();
  }

  @override
  void didUpdateWidget(_SpokenLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) _announce();
  }

  void _announce() {
    if (widget.message.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        widget.message,
        Directionality.of(context),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        widget.message,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: widget.isTrouble ? AppColors.error : AppColors.textPrimary,
            ),
      ),
    );
  }
}

/// A contagem visual. É feedback e nada mais — está escrito ao lado dela.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: AppDimensions.sosButtonSize,
            height: AppDimensions.sosButtonSize,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${seconds < 0 ? 0 : seconds}',
              style: theme.textTheme.displaySmall
                  ?.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.md),
        Expanded(
          child: Text(
            SosCopy.countdown(seconds),
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Explicação calma: fundo neutro, texto legível, sem alarme.
class _QuietNote extends StatelessWidget {
  const _QuietNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

/// Alguma coisa não deu certo — e a frase já vem do dicionário em português.
class _TroubleNote extends StatelessWidget {
  const _TroubleNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(color: AppColors.error),
      ),
    );
  }
}

/// Botão de alvo grande (≥64dp de altura), rótulo inteiro e sem abreviação.
class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.background,
    this.helper,
    this.semanticsLabel,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Cor de fundo. Nulo = botão de contorno, para o que não é a ação principal
  /// daquele estado.
  final Color? background;
  final String? helper;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppDimensions.lg),
              const SizedBox(width: AppDimensions.sm),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  // O rótulo lido pode ser mais explícito que o escrito
                  // ("Cancelar o pedido de ajuda" para "Foi engano — cancelar")
                  // sem que o botão perca a semântica de botão.
                  semanticsLabel: semanticsLabel,
                ),
              ),
            ],
          ),
          if (helper != null) ...[
            const SizedBox(height: AppDimensions.xs),
            Text(
              helper!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: background == null
                        ? AppColors.textSecondary
                        : Colors.white,
                  ),
            ),
          ],
        ],
      ),
    );

    final button = background == null
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppDimensions.sosButtonSize),
            ),
            child: child,
          )
        : FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: background,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(AppDimensions.sosButtonSize),
            ),
            child: child,
          );

    return button;
  }
}
