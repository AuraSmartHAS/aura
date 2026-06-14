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
                  padding: const EdgeInsets.all(AppDimensions.lg),
                  child: Text(
                    'Olá, ${state.userName}',
                    // Patient surface: large title (>=32sp).
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ),
                Expanded(child: _Transcript(state: state)),
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.lg),
                  child: Column(
                    children: [
                      if (state.errorMessage != null)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppDimensions.md),
                          child: Text(
                            state.errorMessage!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.error),
                          ),
                        ),
                      BigMicButton(
                        state: _toMicState(state.voiceState),
                        onTap: () => context
                            .read<HomeBloc>()
                            .add(const HomeMicTappedEvent()),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      Text(
                        _micStateText(state.voiceState),
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      // RN-008 / UI-02: keyboard fallback always available.
                      KeyboardFallbackBar(
                        actions: [
                          FallbackAction(
                            label: 'Falar com a Aura',
                            icon: Icons.touch_app,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: state.transcript.isEmpty
          ? Center(
              child: Text(
                'Comece uma conversa',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppDimensions.md),
              itemCount: state.transcript.length,
              itemBuilder: (context, index) {
                final message = state.transcript[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                  child: Align(
                    alignment: message.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.md,
                        vertical: AppDimensions.sm,
                      ),
                      decoration: BoxDecoration(
                        color: message.isUser
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: Text(
                        message.text,
                        style:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: message.isUser
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
