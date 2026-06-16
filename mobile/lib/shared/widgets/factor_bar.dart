import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../models/severity_level.dart';

/// Resolves the clinical severity color (green · amber · red).
Color severityColor(SeverityLevel level) => switch (level) {
      SeverityLevel.ok => AppColors.careGreen,
      SeverityLevel.attention => AppColors.warning,
      SeverityLevel.high => AppColors.error,
    };

/// The AURA signature: a single weighted factor rendered as a labeled,
/// readable bar — "mostra o porquê". Each driver of a risk or recommendation
/// shows its name, an optional observable trigger, and a bar sized by its
/// weight and colored by severity. This is the product principle made visible:
/// never "the AI suggested" without the why.
class FactorBar extends StatelessWidget {
  const FactorBar({
    super.key,
    required this.label,
    required this.weight,
    required this.level,
    this.icon,
  });

  /// Human factor name, e.g. "piso molhado".
  final String label;

  /// Relative weight in 0..1 (values outside are clamped).
  final double weight;

  final SeverityLevel level;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = severityColor(level);
    final fraction = weight.clamp(0.0, 1.0);
    final percent = (fraction * 100).round();

    return Semantics(
      label: '$label, peso $percent por cento',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: AppDimensions.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: text.labelMedium
                              ?.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Text(
                        '$percent%',
                        style: text.labelSmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Rail + left-anchored fill. SizedBox gives the bar a bounded
                  // height and full width; StackFit.expand makes the track fill
                  // the rail so the fraction lays out left-to-right.
                  SizedBox(
                    height: 10,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: AppColors.surfaceVariant),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: fraction,
                            child: ColoredBox(color: color),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
