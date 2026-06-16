import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/models/order_stage.dart';
import '../../../../shared/models/severity_level.dart';
import '../../../../shared/widgets/async_state_views.dart';
import '../../../../shared/widgets/order_stage_tracker.dart';
import '../../../../shared/widgets/severity_chip.dart';
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
    final isTerminal = order.stage == OrderStage.installed ||
        order.stage == OrderStage.returned;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.lg),
      children: [
        _OrderHeader(order: order),
        const SizedBox(height: AppDimensions.lg),

        // Hero: the time-critical SLA.
        if (order.slaDueAt != null) ...[
          _SlaHeroCard(dueAt: order.slaDueAt!, breached: order.slaBreached),
          const SizedBox(height: AppDimensions.lg),
        ],

        // ETA / distance as clean info tiles.
        if (order.eta != null || order.distanceM != null) ...[
          _InfoTileRow(order: order),
          const SizedBox(height: AppDimensions.lg),
        ],

        // Timeline.
        _SectionCard(
          title: 'Etapas da entrega',
          child: OrderStageTracker(stage: order.stage),
        ),

        const SizedBox(height: AppDimensions.lg),

        if (order.hasRoute)
          SizedBox(
            height: AppDimensions.minTouchTarget,
            child: OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.map(order.orderId)),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Ver rota no mapa'),
            ),
          ),

        // Secondary demo control — visually separated from real actions.
        if (!isTerminal) ...[
          const SizedBox(height: AppDimensions.xl),
          const Divider(color: AppColors.borderColor, height: 1),
          const SizedBox(height: AppDimensions.md),
          _DemoAdvanceControl(order: order, isAdvancing: isAdvancing),
        ],
      ],
    );
  }
}

/// Identifies the order: a clear title plus its reference and live status.
class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final statusLabel = _deliveryStatusLabel(order);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pedido', style: text.labelLarge?.copyWith(
          color: AppColors.textSecondary,
        )),
        const SizedBox(height: AppDimensions.xs),
        Text(
          'Pedido #${_shortId(order.orderId)}',
          style: text.headlineSmall,
        ),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                statusLabel,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _shortId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8).toUpperCase();
  }

  static String _deliveryStatusLabel(OrderDetail order) {
    if (order.installedAt != null) {
      final d = DateFormat('dd/MM HH:mm').format(order.installedAt!.toLocal());
      return 'Instalado em $d';
    }
    if (order.deliveredAt != null) {
      final d = DateFormat('dd/MM HH:mm').format(order.deliveredAt!.toLocal());
      return 'Entregue em $d';
    }
    return 'Etapa atual: ${order.stage.label}';
  }
}

/// The focal element: a prominent SLA countdown / deadline card. When the SLA
/// is breached it switches to a real alert treatment (red surface + a strong
/// severity banner), not a single red text row.
class _SlaHeroCard extends StatelessWidget {
  const _SlaHeroCard({required this.dueAt, required this.breached});

  final DateTime dueAt;
  final bool breached;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final local = dueAt.toLocal();
    final now = DateTime.now();
    final remaining = local.difference(now);
    final overdue = breached || remaining.isNegative;

    final accent = overdue ? AppColors.error : AppColors.primary;
    final bg = overdue
        ? AppColors.error.withValues(alpha: 0.08)
        : AppColors.surface;

    final dueText = DateFormat("dd/MM 'às' HH:mm").format(local);
    final countdown = _formatDuration(remaining.abs());

    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: accent, width: overdue ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                overdue ? Icons.warning_amber_rounded : Icons.timer_outlined,
                size: 22,
                color: accent,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  'Prazo de atendimento (SLA)',
                  style: text.titleMedium?.copyWith(color: accent),
                ),
              ),
            ],
          ),
          if (overdue) ...[
            const SizedBox(height: AppDimensions.md),
            const SeverityChip(level: SeverityLevel.high, strong: true),
          ],
          const SizedBox(height: AppDimensions.md),
          Text(
            overdue ? 'Atrasado há' : 'Tempo restante',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            countdown,
            style: text.displaySmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              const Icon(Icons.event_outlined,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  overdue
                      ? 'Vencido em $dueText'
                      : 'Vence em $dueText',
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    if (days > 0) {
      return '${days}d ${hours}h';
    }
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }
}

/// ETA + distance as flat info tiles side by side.
class _InfoTileRow extends StatelessWidget {
  const _InfoTileRow({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM HH:mm');
    final tiles = <Widget>[
      if (order.eta != null)
        _InfoTile(
          icon: Icons.local_shipping_outlined,
          label: 'Previsão de entrega',
          value: df.format(order.eta!.toLocal()),
        ),
      if (order.distanceM != null)
        _InfoTile(
          icon: Icons.route_outlined,
          label: 'Distância',
          value: '${(order.distanceM! / 1000).toStringAsFixed(1)} km',
        ),
    ];

    if (tiles.length == 1) {
      return tiles.first;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: tiles[0]),
        const SizedBox(width: AppDimensions.md),
        Expanded(child: tiles[1]),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: AppDimensions.sm),
          Text(
            label,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            value,
            style: text.titleMedium?.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Flat card on the warm background with a quiet section title.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.titleSmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.md),
          child,
        ],
      ),
    );
  }
}

/// De-emphasized demo control. Functional (advances a stage in the live demo)
/// but clearly secondary: an outlined button under a labeled, separated zone.
class _DemoAdvanceControl extends StatelessWidget {
  const _DemoAdvanceControl({required this.order, required this.isAdvancing});

  final OrderDetail order;
  final bool isAdvancing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Controle de demonstração',
          style: text.labelMedium?.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: AppDimensions.sm),
        SizedBox(
          height: AppDimensions.minTouchTarget,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.borderColor),
            ),
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
                : const Icon(Icons.fast_forward, size: 18),
            label: const Text('Avançar etapa (demo)'),
          ),
        ),
      ],
    );
  }
}
