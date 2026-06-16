import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../models/order_stage.dart';
import '../models/severity_level.dart';
import 'factor_bar.dart';
import 'order_stage_tracker.dart';
import 'severity_chip.dart';

/// The explainable recommendation card — the product's soul (spec 06/07).
///
/// It ALWAYS shows product + price + reason + factors/weights + norm (NBR 9050)
/// so 100% of recommendations display the "why" (UI-10, RN guardrail). The
/// approve button is the single door to an order (RN-022) and reads as a green
/// "confirm/commit" action. A severity-colored spine makes risk drive the card.
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
    final accent = severityColor(level);
    final priceLabel =
        price != null ? 'R\$ ${price!.toStringAsFixed(2)}' : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      clipBehavior: Clip.antiAlias,
      // Stack (not IntrinsicHeight) so the severity spine spans full height in a
      // single layout pass — FactorBar's FractionallySizedBox does not support
      // intrinsic dimensions, which IntrinsicHeight would force.
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 5, color: accent),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.md + 5,
              AppDimensions.md,
              AppDimensions.md,
              AppDimensions.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SeverityChip(level: level),
                    const Spacer(),
                    if (priceLabel != null)
                      Text(
                        priceLabel,
                        style:
                            text.titleMedium?.copyWith(color: AppColors.primary),
                      ),
                  ],
                ),
                const SizedBox(height: AppDimensions.sm),
                Text(productName, style: text.titleLarge),
                const SizedBox(height: AppDimensions.md),

                // The "why" — always visible.
                _ReasonBlock(reason: reason, normRef: normRef),

                if (factors.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.md),
                  Text('O que pesou',
                      style: text.labelMedium
                          ?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppDimensions.xs),
                  for (var i = 0; i < factors.length; i++)
                    FactorBar(
                      label: _humanize(factors[i]),
                      weight: i < weights.length ? weights[i] : 0,
                      level: level,
                      icon: _factorIcon(factors[i]),
                    ),
                ],

                if (stage != null) ...[
                  const SizedBox(height: AppDimensions.md),
                  OrderStageTracker(stage: stage!),
                ],

                if (onApprove != null && stage == null) ...[
                  const SizedBox(height: AppDimensions.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isApproving ? null : onApprove,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.confirm,
                      ),
                      icon: isApproving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label:
                          Text(isApproving ? 'Enviando…' : 'Aprovar e pedir'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _humanize(String factor) => factor.replaceAll('_', ' ');

  IconData _factorIcon(String factor) {
    final s = factor.toLowerCase();
    if (s.contains('piso') || s.contains('molhad')) {
      return Icons.water_drop_outlined;
    }
    if (s.contains('tapete')) return Icons.layers_outlined;
    if (s.contains('barra') || s.contains('apoio')) {
      return Icons.accessible_outlined;
    }
    if (s.contains('luz') || s.contains('ilumin')) {
      return Icons.lightbulb_outline;
    }
    if (s.contains('escada') || s.contains('degrau')) return Icons.stairs_outlined;
    if (s.contains('mobil') || s.contains('marcha')) return Icons.directions_walk;
    if (s.contains('sono')) return Icons.bedtime_outlined;
    if (s.contains('cogni') || s.contains('memor')) return Icons.psychology_outlined;
    if (s.contains('banh')) return Icons.bathtub_outlined;
    return Icons.insights_outlined;
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
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Por que recomendamos',
                style:
                    text.labelMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppDimensions.xs),
            Text(reason, style: text.bodyMedium),
            if (normRef.trim().isNotEmpty) ...[
              const SizedBox(height: AppDimensions.sm),
              _NormBadge(normRef: normRef),
            ],
          ],
        ),
      ),
    );
  }
}

/// Norm reference (NBR 9050) shown as a small trust badge, not loose text.
class _NormBadge extends StatelessWidget {
  const _NormBadge({required this.normRef});

  final String normRef;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.careGreen),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_outlined,
              size: 16, color: AppColors.careGreen),
          const SizedBox(width: AppDimensions.xs),
          Flexible(
            child: Text(
              normRef,
              style: text.labelSmall?.copyWith(color: AppColors.secondaryDark),
            ),
          ),
        ],
      ),
    );
  }
}
