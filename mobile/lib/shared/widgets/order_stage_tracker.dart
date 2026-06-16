import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../models/order_stage.dart';

/// Vertical logistics timeline (spec 06: Pedido → Separação → Rota → Entregue →
/// Instalado). Each step shows where the order is in the pipeline; the *current*
/// step is emphasized (filled marker, bold petrol label, "Etapa atual" tag) so a
/// caregiver can read the state at a glance. Past steps are connected by a solid
/// petrol rail; future steps are quiet.
class OrderStageTracker extends StatelessWidget {
  const OrderStageTracker({super.key, required this.stage});

  final OrderStage stage;

  static const _stages = [
    OrderStage.approved,
    OrderStage.sourcing,
    OrderStage.inRoute,
    OrderStage.delivered,
    OrderStage.installed,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _stages.indexOf(stage).clamp(0, _stages.length - 1);

    return Semantics(
      container: true,
      label: 'Linha do tempo do pedido. Etapa atual: ${stage.label}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _stages.length; i++)
            _Step(
              label: _stages[i].label,
              done: i < currentIndex,
              current: i == currentIndex,
              isFirst: i == 0,
              isLast: i == _stages.length - 1,
              // The rail above this marker is "filled" once this step is
              // reached; the rail below is filled once the next step is reached.
              railAboveFilled: i <= currentIndex,
              railBelowFilled: i < currentIndex,
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.done,
    required this.current,
    required this.isFirst,
    required this.isLast,
    required this.railAboveFilled,
    required this.railBelowFilled,
  });

  final String label;
  final bool done;
  final bool current;
  final bool isFirst;
  final bool isLast;
  final bool railAboveFilled;
  final bool railBelowFilled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final reached = done || current;
    final markerColor = current
        ? AppColors.primary
        : (done ? AppColors.primary : AppColors.surface);
    final markerBorder = reached ? AppColors.primary : AppColors.borderColor;
    const railColor = AppColors.primary;
    const railIdle = AppColors.dividerColor;

    final labelColor = current
        ? AppColors.primary
        : (done ? AppColors.textPrimary : AppColors.textTertiary);

    final markerSize = current ? 28.0 : 22.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppDimensions.minTouchTarget),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rail + marker column.
            SizedBox(
              width: AppDimensions.xl,
              child: Column(
                children: [
                  // Rail above the marker.
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: isFirst
                            ? Colors.transparent
                            : (railAboveFilled ? railColor : railIdle),
                      ),
                    ),
                  ),
                  // Marker.
                  Container(
                    width: markerSize,
                    height: markerSize,
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: markerBorder, width: 2),
                    ),
                    child: done
                        ? const Icon(Icons.check,
                            size: 14, color: AppColors.surface)
                        : (current
                            ? Center(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.surface,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            : null),
                  ),
                  // Rail below the marker.
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: isLast
                            ? Colors.transparent
                            : (railBelowFilled ? railColor : railIdle),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            // Label column.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: (current ? text.titleMedium : text.bodyLarge)
                          ?.copyWith(
                        color: labelColor,
                        fontWeight:
                            current ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (current) ...[
                      const SizedBox(height: AppDimensions.xs),
                      Text(
                        'Etapa atual',
                        style: text.labelMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
