import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../models/order_stage.dart';

/// Horizontal stepper showing the logistics pipeline progress
/// (spec 06: `●Pedido ○Separação ○Rota ○Entregue ○Instalado`).
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
      label: 'Estágio do pedido: ${stage.label}',
      child: Row(
        children: [
          for (var i = 0; i < _stages.length; i++) ...[
            _Dot(done: i <= currentIndex, label: _stages[i].label),
            if (i < _stages.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  color: i < currentIndex
                      ? AppColors.primary
                      : AppColors.dividerColor,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done, required this.label});

  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.primary : AppColors.textTertiary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: color,
        ),
        const SizedBox(height: AppDimensions.xs),
        SizedBox(
          width: 56,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
