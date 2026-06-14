import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';

/// A single keyboard-fallback action (RN-008).
class FallbackAction {
  const FallbackAction({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Always-available keyboard/touch fallback bar for voice-first flows so that
/// no critical patient flow requires precise reading/touch (RN-008, UI-02).
/// Each button respects the minimum 48dp touch target.
class KeyboardFallbackBar extends StatelessWidget {
  const KeyboardFallbackBar({super.key, required this.actions});

  final List<FallbackAction> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.sm,
      children: [
        for (final action in actions)
          Semantics(
            button: true,
            label: action.label,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTouchTarget,
                minWidth: AppDimensions.minTouchTarget,
              ),
              child: OutlinedButton.icon(
                onPressed: action.onTap,
                icon: Icon(action.icon),
                label: Text(action.label),
              ),
            ),
          ),
      ],
    );
  }
}
