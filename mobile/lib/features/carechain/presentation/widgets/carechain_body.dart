import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/async_state_views.dart';
import '../../../../shared/widgets/explainable_recommendation_card.dart';
import '../approval_copy.dart';
import '../bloc/carechain_bloc.dart';
import 'approval_blocks.dart';
import 'approval_confirmation_sheet.dart';

class CareChainBody extends StatelessWidget {
  const CareChainBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Care-Chain')),
      body: SafeArea(
        child: BlocConsumer<CareChainBloc, CareChainState>(
          listenWhen: (prev, curr) =>
              prev.errorMessage != curr.errorMessage &&
              curr.errorMessage != null,
          listener: (context, state) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          },
          builder: (context, state) {
            return switch (state.status) {
              CareChainStatus.loading =>
                const LoadingView(message: 'Avaliando a casa…'),
              CareChainStatus.error => ErrorRetry(
                  message: state.errorMessage ?? 'Erro ao carregar.',
                  onRetry: () => context
                      .read<CareChainBloc>()
                      .add(const LoadRecommendationEvent()),
                ),
              CareChainStatus.empty => const EmptyState(
                  title: 'Tudo certo por aqui',
                  message: 'Nenhuma recomendação de segurança no momento. '
                      'Quando algo merecer atenção, você verá aqui — sempre '
                      'com o porquê.',
                  icon: Icons.verified_outlined,
                ),
              CareChainStatus.ready => _RecommendationView(state: state),
            };
          },
        ),
      ),
    );
  }
}

class _RecommendationView extends StatelessWidget {
  const _RecommendationView({required this.state});

  final CareChainState state;

  @override
  Widget build(BuildContext context) {
    final reco = state.recommendation!;
    final bloc = context.read<CareChainBloc>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.md,
        AppDimensions.md,
        AppDimensions.xl,
      ),
      children: [
        const _ContextHeader(),
        const SizedBox(height: AppDimensions.md),
        ExplainableRecommendationCard(
          productName: reco.productName,
          priceLabel: ApprovalCopy.priceLabel(reco),
          reason: reco.reason,
          factors: reco.factors,
          factorLabels: reco.factorLabels,
          weights: reco.weights,
          normRef: reco.normRef,
          level: reco.level,
          isApproving: state.isApproving,
          canApprove: state.canApprove,
          approveBlockedReason:
              state.canApprove ? null : ApprovalCopy.approveBlockedWithoutPrice,
          moneySlot: RecommendationPriceBlock(
            recommendation: reco,
            onRetry: state.canApprove
                ? null
                : () => bloc.add(const LoadRecommendationEvent()),
          ),
          installationSlot: InstallationNotice(
            recommendation: reco,
            patientName: state.patientName,
          ),
          onApprove: () => _confirmAndApprove(context, state),
        ),
      ],
    );
  }

  /// Um toque não compra nada: a folha de confirmação é a última parada antes
  /// de o pedido nascer (RN-022).
  Future<void> _confirmAndApprove(
    BuildContext context,
    CareChainState state,
  ) async {
    final bloc = context.read<CareChainBloc>();
    final reco = state.recommendation!;
    final confirmed = await ApprovalConfirmationSheet.show(
      context,
      recommendation: reco,
      patientName: state.patientName,
      address: state.address,
    );
    if (confirmed) {
      bloc.add(ApproveRecommendationEvent(reco.recommendationId));
    }
  }
}

/// Short, warm framing that sets up the explainable card below as the hero:
/// every recommendation comes with the "why", and nothing is ever ordered
/// without the caregiver's approval.
class _ContextHeader extends StatelessWidget {
  const _ContextHeader();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recomendações para a casa que você cuida',
          style: text.headlineSmall,
        ),
        const SizedBox(height: AppDimensions.xs),
        Text(
          'Sugerimos só o que faz a casa mais segura — sempre com o motivo. '
          'Você decide o que aprovar.',
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
