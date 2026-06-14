import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../models/severity_level.dart';
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
class WellbeingDimensionRow extends StatelessWidget {
  const WellbeingDimensionRow({super.key, required this.dimension, this.onTap});

  final WellbeingDimension dimension;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      minVerticalPadding: AppDimensions.sm,
      leading: Icon(dimension.icon),
      title: Text(dimension.label, style: text.titleMedium),
      subtitle:
          dimension.detail != null ? Text(dimension.detail!, style: text.bodySmall) : null,
      trailing: SeverityChip(level: dimension.level),
    );
  }
}
