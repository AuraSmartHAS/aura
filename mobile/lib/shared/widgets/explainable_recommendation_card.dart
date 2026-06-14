import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../models/order_stage.dart';
import '../models/severity_level.dart';
import 'severity_chip.dart';
import 'order_stage_tracker.dart';

/// The explainable recommendation card — the product's soul (spec 06/07).
///
/// It ALWAYS shows product + price + reason + factors/weights + norm (NBR 9050)
/// so 100% of recommendations display the "why" (UI-10, RN guardrail). The
/// approve button is the single door to an order (RN-022).
class ExplainableRecommendationCard extends StatelessWidget {
  const ExplainableRecommendationCard({
    super.key,
    required this.productName,
    required this.price,
    required this.reason,
    required this.factors,
    required this.weights,
    required this.normRef,
    required this.level,
    this.stage,
    this.onApprove,
    this.isApproving = false,
  });

  final String productName;
  final double? price;
  final String reason;
  final List<String> factors;
  final List<double> weights;
  final String normRef;
  final SeverityLevel level;

  /// Non-null once the recommendation became an order.
  final OrderStage? stage;
  final VoidCallback? onApprove;
  final bool isApproving;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final priceLabel =
        price != null ? 'R\$ ${price!.toStringAsFixed(2)}' : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: const BorderSide(color: AppColors.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SeverityChip(level: level),
                const Spacer(),
                if (priceLabel != null)
                  Text(priceLabel,
                      style: text.titleMedium
                          ?.copyWith(color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(productName, style: text.titleLarge),
            const SizedBox(height: AppDimensions.sm),

            // The "why" — always visible.
            _ReasonBlock(reason: reason, normRef: normRef),
            const SizedBox(height: AppDimensions.sm),
            _FactorsBlock(factors: factors, weights: weights),

            const SizedBox(height: AppDimensions.md),
            if (stage != null) ...[
              OrderStageTracker(stage: stage!),
              const SizedBox(height: AppDimensions.sm),
            ],
            if (onApprove != null && stage == null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isApproving ? null : onApprove,
                  child: isApproving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Aprovar e pedir'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReasonBlock extends StatelessWidget {
  const _ReasonBlock({required this.reason, required this.normRef});

  final String reason;
  final String normRef;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: 'Motivo da recomendação: $reason. Norma $normRef.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Porque:', style: text.labelMedium),
            const SizedBox(height: AppDimensions.xs),
            Text(reason, style: text.bodyMedium),
            const SizedBox(height: AppDimensions.xs),
            Text(normRef,
                style: text.bodySmall?.copyWith(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

class _FactorsBlock extends StatelessWidget {
  const _FactorsBlock({required this.factors, required this.weights});

  final List<String> factors;
  final List<double> weights;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.xs,
      children: [
        for (var i = 0; i < factors.length; i++)
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(
              i < weights.length
                  ? '${_humanize(factors[i])} (${weights[i]})'
                  : _humanize(factors[i]),
              style: text.bodySmall,
            ),
          ),
      ],
    );
  }

  String _humanize(String factor) => factor.replaceAll('_', ' ');
}
