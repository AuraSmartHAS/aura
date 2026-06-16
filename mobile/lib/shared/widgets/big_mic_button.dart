import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';

/// Visual state of the patient voice button.
enum MicState { idle, connecting, listening, speaking, error }

/// Giant (>=160dp) accessible microphone button for the patient voice home
/// (spec 06/07: `BigMicButton`).
///
/// AURA's presence is calm, not a neon "AI orb": when active it emits soft,
/// slow concentric rings that breathe outward. Motion is suppressed when the OS
/// requests reduced motion. Large touch target, high contrast, Semantics.
class BigMicButton extends StatefulWidget {
  const BigMicButton({super.key, required this.state, required this.onTap});

  final MicState state;
  final VoidCallback onTap;

  @override
  State<BigMicButton> createState() => _BigMicButtonState();
}

class _BigMicButtonState extends State<BigMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  bool _reduceMotion = false;

  bool get _active =>
      widget.state == MicState.listening ||
      widget.state == MicState.speaking ||
      widget.state == MicState.connecting;

  bool get _shouldAnimate => _active && !_reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(BigMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (_shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_shouldAnimate && _controller.isAnimating) {
      // Stop without resetting value so re-entry resumes the phase smoothly.
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.state) {
      MicState.idle => AppColors.primary,
      MicState.connecting => AppColors.warning,
      MicState.listening => AppColors.primary,
      MicState.speaking => AppColors.careGreen,
      MicState.error => AppColors.error,
    };
    final icon = switch (widget.state) {
      MicState.connecting => Icons.more_horiz,
      MicState.error => Icons.error_outline,
      MicState.speaking => Icons.graphic_eq,
      _ => Icons.mic,
    };

    const core = AppDimensions.bigMicSize; // 160
    const box = core * 1.5; // room for the rings

    return Semantics(
      button: true,
      label: _semanticLabel,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: box,
          height: box,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_shouldAnimate)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      for (final delay in const [0.0, 0.5])
                        _ring(color, (_controller.value + delay) % 1.0),
                    ],
                  ),
                )
              else
                // Calm static halo so the idle mic still has presence.
                Container(
                  width: core + 28,
                  height: core + 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.16),
                      width: 2,
                    ),
                  ),
                ),
              Container(
                width: core,
                height: core,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.22),
                      blurRadius: 28,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 72),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ring(Color color, double t) {
    const core = AppDimensions.bigMicSize;
    final size = core + t * (core * 0.45); // stays within the 240 box
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: (1 - t) * 0.35),
          width: 2,
        ),
      ),
    );
  }

  String get _semanticLabel => switch (widget.state) {
        MicState.idle => 'Microfone. Toque para começar a falar.',
        MicState.connecting => 'Conectando.',
        MicState.listening => 'Escutando você.',
        MicState.speaking => 'Aura está falando.',
        MicState.error => 'Erro na conexão. Toque para tentar de novo.',
      };
}
