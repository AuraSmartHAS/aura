import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../models/severity_level.dart';
import 'factor_bar.dart';

/// Compact colored chip describing a risk/severity level. Used by the 360
/// panel, dashboard and alerts (spec 07: `SeverityChip`).
///
/// Set [strong] for a high-emphasis filled variant (e.g. an alert banner).
class SeverityChip extends StatelessWidget {
  const SeverityChip({super.key, required this.level, this.strong = false});

  final SeverityLevel level;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(level);
    final (icon, label) = switch (level) {
      SeverityLevel.high => (Icons.error_outline, 'Risco alto'),
      SeverityLevel.attention => (Icons.warning_amber_rounded, 'Atenção'),
      SeverityLevel.ok => (Icons.check_circle_outline, 'Tudo ok'),
    };

    final bg = strong ? color : color.withValues(alpha: 0.12);
    final fg = strong ? Colors.white : color;

    return Semantics(
      label: 'Nível de risco: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: color, width: strong ? 0 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: AppDimensions.xs),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
