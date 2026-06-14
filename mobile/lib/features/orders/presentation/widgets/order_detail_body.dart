import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/models/order_stage.dart';
import '../../../../shared/widgets/async_state_views.dart';
import '../../../../shared/widgets/order_stage_tracker.dart';
import '../../domain/entities/order_detail.dart';
import '../bloc/order_tracking_bloc.dart';

class OrderDetailBody extends StatelessWidget {
  const OrderDetailBody({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acompanhar pedido')),
      body: SafeArea(
        child: BlocConsumer<OrderTrackingBloc, OrderTrackingState>(
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
              OrderTrackingStatus.loading => const LoadingView(),
              OrderTrackingStatus.error => ErrorRetry(
                  message: state.errorMessage ?? 'Erro ao carregar.',
                  onRetry: () => context
                      .read<OrderTrackingBloc>()
                      .add(LoadOrderEvent(orderId)),
                ),
              OrderTrackingStatus.ready =>
                _OrderContent(order: state.order!, isAdvancing: state.isAdvancing),
            };
          },
        ),
      ),
    );
  }
}

class _OrderContent extends StatelessWidget {
  const _OrderContent({required this.order, required this.isAdvancing});

  final OrderDetail order;
  final bool isAdvancing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final df = DateFormat('dd/MM HH:mm');
    final isTerminal = order.stage == OrderStage.installed ||
        order.stage == OrderStage.returned;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.lg),
      children: [
        Text('Estágio atual: ${order.stage.label}', style: text.titleMedium),
        const SizedBox(height: AppDimensions.lg),
        OrderStageTracker(stage: order.stage),
        const SizedBox(height: AppDimensions.xl),

        if (order.slaDueAt != null)
          _InfoRow(
            icon: order.slaBreached ? Icons.warning_amber : Icons.schedule,
            label: 'Prazo (SLA)',
            value: df.format(order.slaDueAt!.toLocal()),
            highlight: order.slaBreached,
          ),
        if (order.eta != null)
          _InfoRow(
            icon: Icons.local_shipping_outlined,
            label: 'Previsão de entrega',
            value: df.format(order.eta!.toLocal()),
          ),
        if (order.distanceM != null)
          _InfoRow(
            icon: Icons.route_outlined,
            label: 'Distância',
            value: '${(order.distanceM! / 1000).toStringAsFixed(1)} km',
          ),

        const SizedBox(height: AppDimensions.lg),
        if (order.hasRoute)
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.map(order.orderId)),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Ver rota no mapa'),
          ),
        const SizedBox(height: AppDimensions.sm),

        // Demo control: simulate logistics advancing one stage.
        if (!isTerminal)
          FilledButton.icon(
            onPressed: isAdvancing
                ? null
                : () => context
                    .read<OrderTrackingBloc>()
                    .add(AdvanceOrderEvent(order.orderId)),
            icon: isAdvancing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fast_forward),
            label: const Text('Avançar estágio (simulado)'),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = highlight ? AppColors.error : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppDimensions.sm),
          Text(label, style: text.bodyMedium),
          const Spacer(),
          Text(value, style: text.bodyMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}
