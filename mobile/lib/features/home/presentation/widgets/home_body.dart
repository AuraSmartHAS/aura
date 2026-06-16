import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/big_mic_button.dart';
import '../../../../shared/widgets/keyboard_fallback_bar.dart';
import '../bloc/home_bloc.dart';

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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.lg,
                    AppDimensions.lg,
                    AppDimensions.lg,
                    AppDimensions.sm,
                  ),
                  child: Text(
                    'Olá, ${state.userName}',
                    // Patient surface: large warm greeting (>=32sp).
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ),
                Expanded(child: _Transcript(state: state)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.lg,
                    AppDimensions.md,
                    AppDimensions.lg,
                    AppDimensions.lg,
                  ),
                  child: Column(
                    children: [
                      if (state.errorMessage != null)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppDimensions.md),
                          child: Text(
                            state.errorMessage!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: AppColors.error),
                          ),
                        ),
                      // Hero: the giant accessible mic button stays centered.
                      BigMicButton(
                        state: _toMicState(state.voiceState),
                        onTap: () => context
                            .read<HomeBloc>()
                            .add(const HomeMicTappedEvent()),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        _micStateText(state.voiceState),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      // RN-008 / UI-02: keyboard fallback always available — a
                      // distinct "prefiro digitar" affordance, not a copy of
                      // the mic. Wiring preserved (dispatches HomeMicTapped).
                      KeyboardFallbackBar(
                        actions: [
                          FallbackAction(
                            label: 'Prefiro digitar',
                            icon: Icons.keyboard_outlined,
                            onTap: () => context
                                .read<HomeBloc>()
                                .add(const HomeMicTappedEvent()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
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

  String _micStateText(VoiceUIState state) {
    switch (state) {
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

class _Transcript extends StatelessWidget {
  const _Transcript({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    if (state.transcript.isEmpty) {
      return const _EmptyTranscript();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        AppDimensions.md,
      ),
      itemCount: state.transcript.length,
      itemBuilder: (context, index) {
        final message = state.transcript[index];
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
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
              'Sou a Aura. Toque no microfone e fale comigo — '
              'estou aqui para te ouvir, com calma.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
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
