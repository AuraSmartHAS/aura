import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/big_mic_button.dart';
import '../../../../shared/widgets/keyboard_fallback_bar.dart';
import '../bloc/home_bloc.dart';
import 'text_fallback_panel.dart';

class HomeBody extends StatelessWidget {
  const HomeBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AURA',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                letterSpacing: 4,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Sobre e sair',
            onPressed: () => context.push(AppRoutes.credits),
          ),
        ],
      ),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  _GreetingRow(userName: state.userName),
                  Expanded(child: _Transcript(state: state)),
                  // O rodapé cresce muito (microfone, aviso, chips, campo de
                  // texto) e ainda pode crescer de novo com a fonte do sistema
                  // aumentada. Teto + rolagem própria: nada some da tela nem
                  // estoura o layout em aparelho pequeno.
                  ConstrainedBox(
                    constraints:
                        BoxConstraints(maxHeight: constraints.maxHeight * 0.7),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.lg,
                        AppDimensions.md,
                        AppDimensions.lg,
                        AppDimensions.lg,
                      ),
                      child: _BottomPanel(state: state),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Saudação da Maria com o espaço do SOS reservado à direita.
class _GreetingRow extends StatelessWidget {
  const _GreetingRow({required this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.lg,
        AppDimensions.lg,
        AppDimensions.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Olá, $userName',
              // Patient surface: large warm greeting (>=32sp).
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
          // C3 (SOS): o botão de emergência entra aqui, ancorado no topo. Com o
          // teclado aberto quem encolhe é o rodapé, então o SOS neste ponto
          // nunca fica coberto nem empurrado para fora da tela.
          const SizedBox.square(dimension: AppDimensions.sosButtonSize),
        ],
      ),
    );
  }
}

/// Rodapé da conversa: erro, aviso e — conforme a escolha da Maria — o
/// microfone ou o caminho escrito.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<HomeBloc>();
    void send(String message) => bloc.add(HomeTextSubmittedEvent(message));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.md),
            child: Semantics(
              liveRegion: true,
              child: Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.error),
              ),
            ),
          ),
        if (state.notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.md),
            child: _NoticeBanner(
              message: state.notice!,
              noticeId: state.noticeId,
            ),
          ),
        if (state.isTextMode)
          TextFallbackPanel(
            intentsHighlighted: state.intentsHighlighted,
            onSend: send,
            onRepeat: () => bloc.add(const HomeRepeatLastReplyEvent()),
            onVoice: () => bloc.add(const HomeVoiceModeRequestedEvent()),
          )
        else ...[
          // Hero: the giant accessible mic button stays centered.
          Center(
            child: BigMicButton(
              state: _toMicState(state.voiceState),
              onTap: () => bloc.add(const HomeMicTappedEvent()),
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            _micStateText(state),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: AppColors.textPrimary),
          ),
          if (state.intentsHighlighted) ...[
            const SizedBox(height: AppDimensions.md),
            IntentChipsRow(onIntent: send, highlighted: true),
          ],
          const SizedBox(height: AppDimensions.md),
          // RN-008 / UI-02 / C4: o fallback é um caminho de verdade — "Prefiro
          // digitar" abre o campo de texto, nunca liga o microfone (R-10).
          KeyboardFallbackBar(
            actions: [
              FallbackAction(
                label: 'Prefiro digitar',
                icon: Icons.keyboard_outlined,
                onTap: () => bloc.add(const HomeTextModeRequestedEvent()),
              ),
              // Só aparece quando existe fala para repetir — no começo da
              // conversa seria um botão que não faz nada.
              if (state.lastAuraReply != null)
                FallbackAction(
                  label: 'Ouvir de novo',
                  icon: Icons.replay,
                  onTap: () => bloc.add(const HomeRepeatLastReplyEvent()),
                ),
            ],
          ),
        ],
      ],
    );
  }

  MicState _toMicState(VoiceUIState state) {
    switch (state) {
      case VoiceUIState.idle:
        return MicState.idle;
      case VoiceUIState.connecting:
        return MicState.connecting;
      case VoiceUIState.listening:
        return MicState.listening;
      case VoiceUIState.speaking:
        return MicState.speaking;
      case VoiceUIState.error:
        return MicState.error;
    }
  }

  String _micStateText(HomeState state) {
    if (state.isMuted && state.isSessionLive) {
      return 'Microfone desligado. Toque para falar.';
    }
    switch (state.voiceState) {
      case VoiceUIState.idle:
        return 'Toque para começar';
      case VoiceUIState.connecting:
        return 'Conectando...';
      case VoiceUIState.listening:
        return 'Escutando...';
      case VoiceUIState.speaking:
        return 'Falando...';
      case VoiceUIState.error:
        return 'Erro na conexão';
    }
  }
}

/// Aviso calmo da Aura ("Não te ouvi bem", a última fala repetida). Cada aviso
/// novo é anunciado ao leitor de tela — é o que faz "Ouvir de novo" servir a
/// quem não enxerga o balão.
class _NoticeBanner extends StatefulWidget {
  const _NoticeBanner({required this.message, required this.noticeId});

  final String message;
  final int noticeId;

  @override
  State<_NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends State<_NoticeBanner> {
  @override
  void initState() {
    super.initState();
    _announce();
  }

  @override
  void didUpdateWidget(_NoticeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.noticeId != oldWidget.noticeId) {
      _announce();
    }
  }

  void _announce() {
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
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: Text(
          widget.message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
        ),
      ),
    );
  }
}

/// Transcript da conversa. Rola sozinho até a última mensagem: sem isso, o que
/// a Maria acabou de dizer (ou escrever) some abaixo da dobra.
class _Transcript extends StatefulWidget {
  const _Transcript({required this.state});

  final HomeState state;

  @override
  State<_Transcript> createState() => _TranscriptState();
}

class _TranscriptState extends State<_Transcript> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(_Transcript oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.transcript.length != oldWidget.state.transcript.length) {
      _scrollToLatest();
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.transcript.isEmpty) {
      return const _EmptyTranscript();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        AppDimensions.md,
      ),
      itemCount: widget.state.transcript.length,
      itemBuilder: (context, index) {
        final message = widget.state.transcript[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.md),
          child: _ChatBubble(text: message.text, isUser: message.isUser),
        );
      },
    );
  }
}

/// Warm, welcoming empty state: AURA has a face and an invitation — not a cold
/// bordered box. This is the patient's first impression of "her".
class _EmptyTranscript extends StatelessWidget {
  const _EmptyTranscript();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Centraliza quando cabe e rola quando não cabe — com o teclado aberto (ou
    // a fonte do sistema aumentada) esta área encolhe bastante.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.xl,
                vertical: AppDimensions.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // AURA's identity mark — a calm, friendly presence.
                  const _AuraAvatar(),
                  const SizedBox(height: AppDimensions.lg),
                  Text(
                    'Olá, vamos conversar?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'Sou a Aura. Fale comigo pelo microfone ou toque em '
                    '"Prefiro digitar" — do jeito que for mais fácil para você.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// AURA's avatar / identity mark: a soft petrol disc holding a gentle
/// "presence" glyph. Decorative — hidden from screen readers.
class _AuraAvatar extends StatelessWidget {
  const _AuraAvatar();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: AppDimensions.xxl * 2,
        height: AppDimensions.xxl * 2,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.spatial_audio_off,
          size: AppDimensions.xxl,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Asymmetric chat bubble. The user speaks in solid petrol; Aura answers in a
/// clearly differentiated soft petrol surface so her voice is never invisible.
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final bubbleColor = isUser ? AppColors.primary : scheme.primaryContainer;
    final textColor =
        isUser ? Colors.white : scheme.onPrimaryContainer;

    // Asymmetric corners: a small "tail" corner on the sender's side.
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppDimensions.radiusLg),
      topRight: const Radius.circular(AppDimensions.radiusLg),
      bottomLeft: Radius.circular(
          isUser ? AppDimensions.radiusLg : AppDimensions.radiusSm),
      bottomRight: Radius.circular(
          isUser ? AppDimensions.radiusSm : AppDimensions.radiusLg),
    );

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.82,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.md,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: radius,
      ),
      child: Text(
        text,
        // Patient body: large, legible (>=18sp via bodyLarge).
        style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
      ),
    );

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Quiet speaker label so each side is identifiable beyond color.
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimensions.xs,
            right: AppDimensions.xs,
            bottom: AppDimensions.xs,
          ),
          child: Text(
            isUser ? 'Você' : 'Aura',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: AppColors.textTertiary),
          ),
        ),
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: bubble,
        ),
      ],
    );
  }
}
