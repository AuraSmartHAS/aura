import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/async_state_views.dart';
import '../../../../shared/widgets/severity_chip.dart';
import '../bloc/dashboard_bloc.dart';

class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AURA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(AppRoutes.credits),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            return switch (state.status) {
              DashboardStatus.loading => const LoadingView(),
              DashboardStatus.error => ErrorRetry(
                  message: state.errorMessage ?? 'Erro ao carregar.',
                  onRetry: () => context
                      .read<DashboardBloc>()
                      .add(const LoadDashboardEvent()),
                ),
              DashboardStatus.ready => RefreshIndicator(
                  onRefresh: () async => context
                      .read<DashboardBloc>()
                      .add(const LoadDashboardEvent()),
                  child: _DashboardContent(state: state),
                ),
            };
          },
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final detail = state.homeDetail!;
    final top = state.topScore;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        Text('Status do dia', style: text.headlineMedium),
        const SizedBox(height: AppDimensions.sm),

        // Home card
        Card(
          child: ListTile(
            leading: const Icon(Icons.home_outlined),
            title: Text(detail.patientName ?? detail.home.label),
            subtitle: Text(detail.home.address),
          ),
        ),
        const SizedBox(height: AppDimensions.sm),

        // Top risk
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Maior risco agora', style: text.labelLarge),
                      const SizedBox(height: AppDimensions.xs),
                      Text(
                        top == null
                            ? 'Sem leituras ainda'
                            : top.dimension.label,
                        style: text.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (top != null) SeverityChip(level: top.level),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.lg),

        Text('Atalhos', style: text.titleMedium),
        const SizedBox(height: AppDimensions.sm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppDimensions.sm,
          crossAxisSpacing: AppDimensions.sm,
          childAspectRatio: 1.6,
          children: const [
            _ShortcutCard(
              icon: Icons.monitor_heart_outlined,
              label: 'Monitoramento 360',
              route: AppRoutes.wellbeing,
            ),
            _ShortcutCard(
              icon: Icons.recommend_outlined,
              label: 'Care-Chain',
              route: AppRoutes.careChain,
            ),
            _ShortcutCard(
              icon: Icons.medication_outlined,
              label: 'Medicamentos',
              route: AppRoutes.medications,
            ),
            _ShortcutCard(
              icon: Icons.watch_outlined,
              label: 'Wearable',
              route: AppRoutes.wearable,
            ),
          ],
        ),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: AppColors.primary),
              const SizedBox(height: AppDimensions.sm),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
