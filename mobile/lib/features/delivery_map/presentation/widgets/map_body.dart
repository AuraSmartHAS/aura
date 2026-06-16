import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/async_state_views.dart';
import '../../../../shared/widgets/map_panel.dart';
import '../../../../shared/widgets/order_stage_tracker.dart';
import '../../../orders/domain/entities/order_detail.dart';
import '../bloc/map_bloc.dart';

class MapBody extends StatefulWidget {
  const MapBody({super.key});

  @override
  State<MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends State<MapBody> {
  // Remembered so the error-state retry can dispatch the real reload event.
  String? _orderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rota da entrega')),
      body: SafeArea(
        child: BlocBuilder<MapBloc, MapState>(
          builder: (context, state) {
            // Keep the last known order id available for a real retry.
            final id = state.order?.orderId;
            if (id != null) _orderId = id;

            return switch (state.status) {
              MapStatus.loading =>
                const LoadingView(message: 'Carregando a rota da entrega…'),
              MapStatus.error => ErrorRetry(
                  message: state.errorMessage ?? 'Erro ao carregar.',
                  onRetry: _orderId == null
                      ? () {}
                      : () =>
                          context.read<MapBloc>().add(LoadMapEvent(_orderId!)),
                ),
              MapStatus.ready => _MapView(
                  order: state.order!,
                  hasLocation: state.hasLocation,
                ),
            };
          },
        ),
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({required this.order, required this.hasLocation});

  final OrderDetail order;
  final bool hasLocation;

  @override
  Widget build(BuildContext context) {
    if (!order.hasRoute) {
      return const EmptyState(
        title: 'Rota a caminho',
        message: 'A rota desta entrega ainda não está disponível. '
            'Assim que sair para entrega, ela aparece aqui.',
        icon: Icons.map_outlined,
      );
    }

    // GeoJSON stores [lng, lat]; Google Maps wants LatLng(lat, lng).
    final route =
        order.routeCoordinates.map((c) => LatLng(c[1], c[0])).toList();
    final node = route.first;
    final home = route.last;
    final etaLabel = order.eta != null
        ? DateFormat('HH:mm').format(order.eta!.toLocal())
        : null;
    final distanceLabel = _distanceLabel(order.distanceM);
    final durationLabel = _durationLabel(order.durationS);

    // Full-bleed map; order context lives in the bottom panel overlay.
    return Stack(
      children: [
        Positioned.fill(
          child: MapPanel(
            home: home,
            node: node,
            delivery: home,
            route: route,
            etaLabel: etaLabel,
            distanceLabel: distanceLabel,
            durationLabel: durationLabel,
            fill: true,
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _OrderContextPanel(
            order: order,
            hasLocation: hasLocation,
            etaLabel: etaLabel,
            distanceLabel: distanceLabel,
            durationLabel: durationLabel,
          ),
        ),
      ],
    );
  }

  static String? _distanceLabel(int? meters) {
    if (meters == null) return null;
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(km >= 10 ? 0 : 1).replaceAll('.', ',')} km';
    }
    return '$meters m';
  }

  static String? _durationLabel(int? seconds) {
    if (seconds == null) return null;
    final minutes = (seconds / 60).round();
    if (minutes < 1) return '< 1 min';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
  }
}

/// Calm bottom panel carrying the order context (stage, ETA, route summary,
/// and the location notice) over the full-bleed map.
class _OrderContextPanel extends StatelessWidget {
  const _OrderContextPanel({
    required this.order,
    required this.hasLocation,
    required this.etaLabel,
    required this.distanceLabel,
    required this.durationLabel,
  });

  final OrderDetail order;
  final bool hasLocation;
  final String? etaLabel;
  final String? distanceLabel;
  final String? durationLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final summaryParts = <String>[
      if (durationLabel != null) durationLabel!,
      if (distanceLabel != null) distanceLabel!,
    ];

    // Cap the panel height and scroll its content so large text scales never
    // overflow / clip the order context over the full-bleed map.
    final maxPanelHeight = MediaQuery.sizeOf(context).height * 0.55;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.lg),
      constraints: BoxConstraints(maxHeight: maxPanelHeight),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Headline: arrival time as the focal element of the panel.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        etaLabel != null
                            ? 'Chegada prevista'
                            : order.stage.label,
                        style: text.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.xs),
                      Text(
                        etaLabel != null ? 'Hoje, $etaLabel' : 'Em andamento',
                        style: text.headlineSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (summaryParts.isNotEmpty) ...[
                  const SizedBox(width: AppDimensions.sm),
                  _RouteSummaryChip(parts: summaryParts),
                ],
              ],
            ),
            const SizedBox(height: AppDimensions.lg),
            OrderStageTracker(stage: order.stage),
            const SizedBox(height: AppDimensions.md),
            // Endpoints of the route, read clearly in plain language.
            const _RouteRow(
              icon: Icons.local_shipping_outlined,
              color: AppColors.primary,
              label: 'Saindo do nó logístico',
            ),
            const SizedBox(height: AppDimensions.sm),
            const _RouteRow(
              icon: Icons.home_outlined,
              color: AppColors.careGreen,
              label: 'Entrega na casa',
            ),
            if (!hasLocation) ...[
              const SizedBox(height: AppDimensions.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        'Sem acesso à sua localização. A rota da entrega '
                        'continua sendo exibida normalmente.',
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteSummaryChip extends StatelessWidget {
  const _RouteSummaryChip({required this.parts});

  final List<String> parts;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.route_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: AppDimensions.xs),
          Text(
            parts.join('  ·  '),
            style: text.labelLarge?.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: AppDimensions.xl,
          height: AppDimensions.xl,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
        ),
      ],
    );
  }
}
