import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/recommendation.dart';
import '../approval_copy.dart';

/// A conta do pedido, no lugar onde o dinheiro tem de estar: logo abaixo do
/// produto e antes de qualquer botão.
///
/// Quando o preço não carrega, este bloco **ocupa o mesmo espaço** dizendo que
/// não carregou. O bug que a correção C5 conserta era o oposto: o card escondia
/// o preço e deixava "Aprovar" ativo (CR-5).
class RecommendationPriceBlock extends StatelessWidget {
  const RecommendationPriceBlock({
    super.key,
    required this.recommendation,
    this.onRetry,
  });

  final Recommendation recommendation;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final totalLine = ApprovalCopy.totalLine(recommendation);
    return totalLine == null
        ? _PriceUnavailable(onRetry: onRetry)
        : _TotalBlock(line: totalLine);
  }
}

class _TotalBlock extends StatelessWidget {
  const _TotalBlock({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '${ApprovalCopy.priceTitle}. $line',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceTinted,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _BlockTitle(
              icon: Icons.payments_outlined,
              title: ApprovalCopy.priceTitle,
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(line, style: text.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _PriceUnavailable extends StatelessWidget {
  const _PriceUnavailable({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.error, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: '${ApprovalCopy.priceUnavailableTitle}. '
                '${ApprovalCopy.priceUnavailableMessage}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BlockTitle(
                  icon: Icons.error_outline,
                  title: ApprovalCopy.priceUnavailableTitle,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  ApprovalCopy.priceUnavailableMessage,
                  style: text.bodyMedium,
                ),
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppDimensions.md),
            Semantics(
              button: true,
              label: 'Tentar carregar o preço de novo',
              excludeSemantics: true,
              child: SizedBox(
                height: AppDimensions.minTouchTarget,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar de novo'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Quem entra na casa — a pergunta que uma pessoa real faz antes de deixar um
/// estranho entrar na casa de uma idosa que mora sozinha (AL-11).
class InstallationNotice extends StatelessWidget {
  const InstallationNotice({
    super.key,
    required this.recommendation,
    required this.patientName,
  });

  final Recommendation recommendation;
  final String? patientName;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (!recommendation.needsInstallation) {
      return Semantics(
        label: ApprovalCopy.noInstallation,
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                ApprovalCopy.noInstallation,
                style:
                    text.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final notice = ApprovalCopy.installationNotice(patientName);
    return Semantics(
      label: '${ApprovalCopy.installationTitle}. $notice',
      excludeSemantics: true,
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
            const _BlockTitle(
              icon: Icons.badge_outlined,
              title: ApprovalCopy.installationTitle,
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(notice, style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Ícone + rótulo discreto que abre cada bloco da aprovação.
class _BlockTitle extends StatelessWidget {
  const _BlockTitle({
    required this.icon,
    required this.title,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Text(
            title,
            style: text.labelMedium?.copyWith(
              color:
                  color == AppColors.primary ? AppColors.textSecondary : color,
            ),
          ),
        ),
      ],
    );
  }
}
