import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../models/severity_level.dart';

/// Compact colored chip describing a risk/severity level. Used by the 360
/// panel, dashboard and alerts (spec 07: `SeverityChip`).
class SeverityChip extends StatelessWidget {
  const SeverityChip({super.key, required this.level});

  final SeverityLevel level;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (level) {
      SeverityLevel.high => (AppColors.error, 'Risco alto'),
      SeverityLevel.attention => (AppColors.warning, 'Atenção'),
      SeverityLevel.ok => (AppColors.success, 'Ok'),
    };

    return Semantics(
      label: 'Nível de risco: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm,
          vertical: AppDimensions.xs,
        ),
        decoration: BoxDecoration(
          // ignore: deprecated_member_use
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: AppDimensions.xs),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
