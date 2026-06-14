import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
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
            onPressed: () => context.push(AppRoutes.credits),
          ),
        ],
      ),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Olá, ${state.userName}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: state.transcript.isEmpty
                        ? Center(
                            child: Text(
                              'Comece uma conversa',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: state.transcript.length,
                            itemBuilder: (context, index) {
                              final message = state.transcript[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Align(
                                  alignment: message.isUser
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: message.isUser
                                          ? AppColors.primary
                                          : AppColors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      message.text,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
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
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (state.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            state.errorMessage!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.error,
                                ),
                          ),
                        ),
                      GestureDetector(
                        onTap: () {
                          context.read<HomeBloc>().add(const HomeMicTappedEvent());
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _getMicButtonColor(state.voiceState),
                            shape: BoxShape.circle,
                            boxShadow: [
                              if (state.voiceState != VoiceUIState.idle)
                                BoxShadow(
                                  color: _getMicButtonColor(state.voiceState)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                          child: Icon(
                            _getMicIcon(state.voiceState),
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _getMicStateText(state.voiceState),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
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

  Color _getMicButtonColor(VoiceUIState state) {
    switch (state) {
      case VoiceUIState.idle:
        return AppColors.primary;
      case VoiceUIState.connecting:
        return AppColors.warning;
      case VoiceUIState.listening:
        return AppColors.primary;
      case VoiceUIState.speaking:
        return AppColors.success;
      case VoiceUIState.error:
        return AppColors.error;
    }
  }

  IconData _getMicIcon(VoiceUIState state) {
    switch (state) {
      case VoiceUIState.idle:
        return Icons.mic;
      case VoiceUIState.connecting:
        return Icons.hourglass_empty;
      case VoiceUIState.listening:
        return Icons.mic;
      case VoiceUIState.speaking:
        return Icons.mic;
      case VoiceUIState.error:
        return Icons.error;
    }
  }

  String _getMicStateText(VoiceUIState state) {
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
