import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';

/// A single keyboard-fallback action (RN-008).
class FallbackAction {
  const FallbackAction({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Always-available keyboard/touch fallback for voice-first flows so that no
/// critical patient flow requires speaking (RN-008, UI-02).
///
/// This is a *genuine* alternative to the big mic hero, not a second
/// copy of it: it reads as a quiet, secondary "prefiro digitar / toque aqui"
/// affordance below the mic. Each action is a calm full-width text row with a
/// hairline border, comfortably above the 48dp touch target, and annotated for
/// screen readers.
class KeyboardFallbackBar extends StatelessWidget {
  const KeyboardFallbackBar({super.key, required this.actions});

  final List<FallbackAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.sm),
            child: Semantics(
              button: true,
              label: action.label,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppDimensions.minTouchTarget,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: action.onTap,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.lg,
                        vertical: AppDimensions.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            action.icon,
                            size: AppDimensions.lg,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppDimensions.sm),
                          Flexible(
                            child: Text(
                              action.label,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
