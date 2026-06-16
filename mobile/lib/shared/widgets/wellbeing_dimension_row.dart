import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../models/severity_level.dart';
import 'factor_bar.dart';
import 'severity_chip.dart';

/// One dimension of the 360 wellbeing panel (spec 07: `WellbeingDimensionRow`).
class WellbeingDimension {
  const WellbeingDimension({
    required this.label,
    required this.level,
    required this.icon,
    this.detail,
  });

  final String label;
  final SeverityLevel level;
  final IconData icon;
  final String? detail;
}

/// A single row showing a wellbeing dimension and its severity chip.
///
/// Risk-driven hierarchy: rows that need attention (attention/high) earn a
/// severity-tinted leading container and a thin left accent so the caregiver's
/// eye lands on them first; calm "ok" rows stay flat and quiet.
class WellbeingDimensionRow extends StatelessWidget {
  const WellbeingDimensionRow({super.key, required this.dimension, this.onTap});

  final WellbeingDimension dimension;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = severityColor(dimension.level);
    final emphasised = dimension.level != SeverityLevel.ok;

    // Calm rows: neutral leading on surface. Attention/high: tinted container
    // + a hairline left accent so severity reads pre-attentively (never color
    // alone — the SeverityChip still carries icon + text).
    final leadingBg =
        emphasised ? color.withValues(alpha: 0.12) : AppColors.surfaceVariant;
    final leadingFg = emphasised ? color : AppColors.textSecondary;

    return Semantics(
      button: onTap != null,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Container(
            constraints:
                const BoxConstraints(minHeight: AppDimensions.minTouchTarget),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              // Left accent is part of the border family: a thicker, tinted
              // edge for emphasised rows, hairline for calm ones.
              border: Border(
                left: BorderSide(
                  color: emphasised ? color : AppColors.borderColor,
                  width: emphasised ? 4 : 1,
                ),
                top: const BorderSide(color: AppColors.borderColor),
                right: const BorderSide(color: AppColors.borderColor),
                bottom: const BorderSide(color: AppColors.borderColor),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: AppDimensions.xl + AppDimensions.md,
                  height: AppDimensions.xl + AppDimensions.md,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: leadingBg,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Icon(dimension.icon, color: leadingFg),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              dimension.label,
                              style: text.titleMedium?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: emphasised
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.sm),
                          SeverityChip(level: dimension.level),
                        ],
                      ),
                      if (dimension.detail != null) ...[
                        const SizedBox(height: AppDimensions.xs),
                        Text(
                          dimension.detail!,
                          style: text.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
