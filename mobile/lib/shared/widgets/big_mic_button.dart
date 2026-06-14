import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';

/// Visual state of the patient voice button.
enum MicState { idle, connecting, listening, speaking, error }

/// Giant (>=160dp) accessible microphone button for the patient voice home
/// (spec 06/07: `BigMicButton`). Large touch target, high contrast, Semantics.
class BigMicButton extends StatelessWidget {
  const BigMicButton({super.key, required this.state, required this.onTap});

  final MicState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      MicState.idle => AppColors.primary,
      MicState.connecting => AppColors.warning,
      MicState.listening => AppColors.primary,
      MicState.speaking => AppColors.success,
      MicState.error => AppColors.error,
    };
    final icon = switch (state) {
      MicState.connecting => Icons.hourglass_empty,
      MicState.error => Icons.error_outline,
      _ => Icons.mic,
    };

    return Semantics(
      button: true,
      label: _semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: AppDimensions.bigMicSize,
          height: AppDimensions.bigMicSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              if (state != MicState.idle)
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: color.withOpacity(0.5),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 72),
        ),
      ),
    );
  }

  String get _semanticLabel => switch (state) {
        MicState.idle => 'Microfone. Toque para começar a falar.',
        MicState.connecting => 'Conectando.',
        MicState.listening => 'Escutando você.',
        MicState.speaking => 'Aura está falando.',
        MicState.error => 'Erro na conexão. Toque para tentar de novo.',
      };
}
