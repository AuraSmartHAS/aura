import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/recommendation.dart';
import '../approval_copy.dart';

/// A última tela antes de gastar o dinheiro de alguém (AL-10).
///
/// Repete, em voz de gente, tudo o que a decisão precisa: o item, o total, onde
/// entrega, quem entra na casa e quem paga. Não existe botão de cancelar porque
/// **não existe rota de cancelamento** — em vez de prometer o que não temos, a
/// folha entrega o caminho humano.
class ApprovalConfirmationSheet extends StatelessWidget {
  const ApprovalConfirmationSheet({
    super.key,
    required this.recommendation,
    required this.patientName,
    required this.address,
  });

  final Recommendation recommendation;
  final String? patientName;
  final String? address;

  /// Abre a folha e resolve para `true` quando a cuidadora confirma.
  static Future<bool> show(
    BuildContext context, {
    required Recommendation recommendation,
    required String? patientName,
    required String? address,
  }) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ApprovalConfirmationSheet(
        recommendation: recommendation,
        patientName: patientName,
        address: address,
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final totalLine = ApprovalCopy.totalLine(recommendation);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.lg,
          0,
          AppDimensions.lg,
          AppDimensions.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confirmar a compra', style: text.headlineSmall),
              const SizedBox(height: AppDimensions.xs),
              Text(
                'Confira antes de pedir. Nada é comprado sem você confirmar '
                'aqui.',
                style:
                    text.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimensions.lg),
              _SummaryRow(
                icon: Icons.inventory_2_outlined,
                label: 'Item',
                value: recommendation.productName,
              ),
              _SummaryRow(
                icon: Icons.payments_outlined,
                label: ApprovalCopy.priceTitle,
                value: totalLine ?? ApprovalCopy.priceUnavailableMessage,
                emphasized: totalLine != null,
              ),
              _SummaryRow(
                icon: Icons.location_on_outlined,
                label: 'Endereço',
                value: ApprovalCopy.orderSummaryAddress(patientName, address),
              ),
              _SummaryRow(
                icon: Icons.badge_outlined,
                label: 'Instalação',
                value: recommendation.needsInstallation
                    ? ApprovalCopy.installationNotice(patientName)
                    : ApprovalCopy.noInstallation,
              ),
              const _SummaryRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Quem paga',
                value: ApprovalCopy.payer,
              ),
              const SizedBox(height: AppDimensions.md),
              const _ChangedMindNote(),
              const SizedBox(height: AppDimensions.lg),
              Semantics(
                button: true,
                label: 'Confirmar e pedir '
                    '${recommendation.productName}'
                    '${totalLine == null ? '' : ', $totalLine'}',
                excludeSemantics: true,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.confirm,
                      minimumSize: const Size(0, AppDimensions.minTouchTarget),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Confirmar e pedir'),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              Semantics(
                button: true,
                label: 'Voltar sem pedir',
                excludeSemantics: true,
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, AppDimensions.minTouchTarget),
                    ),
                    child: const Text('Voltar sem pedir'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.labelMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: emphasized ? text.titleMedium : text.bodyMedium,
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

/// Caminho humano no lugar de um botão de cancelar que não existiria de
/// verdade: prometer cancelamento sem rota é pior do que não ter.
class _ChangedMindNote extends StatelessWidget {
  const _ChangedMindNote();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: ApprovalCopy.changedMind,
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.support_agent_outlined,
                size: 20, color: AppColors.primary),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Text(ApprovalCopy.changedMind, style: text.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
