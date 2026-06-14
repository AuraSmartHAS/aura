import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/async_state_views.dart';
import '../../../../shared/widgets/map_panel.dart';
import '../../../orders/domain/entities/order_detail.dart';
import '../bloc/map_bloc.dart';

class MapBody extends StatelessWidget {
  const MapBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rota da entrega')),
      body: SafeArea(
        child: BlocBuilder<MapBloc, MapState>(
          builder: (context, state) {
            return switch (state.status) {
              MapStatus.loading => const LoadingView(),
              MapStatus.error => ErrorRetry(
                  message: state.errorMessage ?? 'Erro ao carregar.',
                  onRetry: () {},
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
        message: 'Rota ainda não disponível para este pedido.',
        icon: Icons.map_outlined,
      );
    }

    // GeoJSON stores [lng, lat]; Google Maps wants LatLng(lat, lng).
    final route = order.routeCoordinates
        .map((c) => LatLng(c[1], c[0]))
        .toList();
    final node = route.first;
    final home = route.last;
    final etaLabel =
        order.eta != null ? DateFormat('HH:mm').format(order.eta!.toLocal()) : null;

    return Column(
      children: [
        if (!hasLocation)
          Container(
            width: double.infinity,
            color: AppColors.surfaceVariant,
            padding: const EdgeInsets.all(AppDimensions.sm),
            child: Row(
              children: [
                const Icon(Icons.location_off_outlined, size: 18),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Text(
                    'Sem acesso à localização. A rota da entrega é exibida '
                    'mesmo assim.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: MapPanel(
              home: home,
              node: node,
              delivery: home,
              route: route,
              etaLabel: etaLabel,
            ),
          ),
        ),
      ],
    );
  }
}
