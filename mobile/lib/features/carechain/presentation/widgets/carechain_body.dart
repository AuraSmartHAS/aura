import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/async_state_views.dart';
import '../../../../shared/widgets/explainable_recommendation_card.dart';
import '../bloc/carechain_bloc.dart';

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
              CareChainStatus.loading => const LoadingView(),
              CareChainStatus.error => ErrorRetry(
                  message: state.errorMessage ?? 'Erro ao carregar.',
                  onRetry: () => context
                      .read<CareChainBloc>()
                      .add(const LoadRecommendationEvent()),
                ),
              CareChainStatus.empty => const EmptyState(
                  message: 'Tudo certo por aqui! Nenhuma recomendação de '
                      'segurança no momento.',
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
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        ExplainableRecommendationCard(
          productName: reco.productName,
          price: reco.price,
          reason: reco.reason,
          factors: reco.factors,
          weights: reco.weights,
          normRef: reco.normRef,
          level: reco.level,
          isApproving: state.isApproving,
          onApprove: () => context
              .read<CareChainBloc>()
              .add(ApproveRecommendationEvent(reco.recommendationId)),
        ),
      ],
    );
  }
}
