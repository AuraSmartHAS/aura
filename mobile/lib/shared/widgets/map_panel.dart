import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';

/// Map showing the logistics geography: home / node / delivery / technician
/// markers plus the route polyline and ETA (spec 07: `MapPanel`).
///
/// Decoupled from feature domain — callers pass plain [LatLng] points. When
/// [fill] is true the map is rendered full-bleed (no rounded clip) so callers
/// can lay their own context panel over it.
class MapPanel extends StatelessWidget {
  const MapPanel({
    super.key,
    required this.home,
    this.node,
    this.delivery,
    this.technician,
    this.route = const [],
    this.etaLabel,
    this.distanceLabel,
    this.durationLabel,
    this.fill = false,
    this.onMapCreated,
  });

  final LatLng home;
  final LatLng? node;
  final LatLng? delivery;
  final LatLng? technician;
  final List<LatLng> route;

  /// Arrival time, e.g. `14:35` (the chip prefixes "Chegada").
  final String? etaLabel;

  /// Optional human route summary (e.g. `3,2 km` and `12 min`) shown beside ETA.
  final String? distanceLabel;
  final String? durationLabel;

  /// Render edge-to-edge (no rounded card) so an overlay panel can sit on top.
  final bool fill;

  final void Function(GoogleMapController)? onMapCreated;

  /// Subtle, calm map styling: muted warm land, hushed POIs and labels so the
  /// branded route + markers stay the focal point (matches the warm palette).
  static const String _mapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f3f1ec"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#6b6257"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#f7f5f1"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#dcd6cb"}]},
  {"featureType":"poi","stylers":[{"visibility":"simplified"}]},
  {"featureType":"poi","elementType":"labels.text","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#dfe7d6"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8377"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#f2efe9"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#e8e3d9"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#cdddde"}]}
]
''';

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('home'),
        position: home,
        infoWindow: const InfoWindow(title: 'Casa'),
      ),
      if (node != null)
        Marker(
          markerId: const MarkerId('node'),
          position: node!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Nó logístico'),
        ),
      if (delivery != null)
        Marker(
          markerId: const MarkerId('delivery'),
          position: delivery!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Entrega'),
        ),
      if (technician != null)
        Marker(
          markerId: const MarkerId('technician'),
          position: technician!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Técnico'),
        ),
    };

    final polylines = <Polyline>{
      // Soft halo under the route for legibility on busy map tiles.
      if (route.length >= 2)
        Polyline(
          polylineId: const PolylineId('route_halo'),
          points: route,
          color: AppColors.surface,
          width: 9,
        ),
      if (route.length >= 2)
        Polyline(
          polylineId: const PolylineId('route'),
          points: route,
          color: AppColors.primary,
          width: 5,
        ),
    };

    final map = GoogleMap(
      initialCameraPosition: CameraPosition(target: home, zoom: 13),
      markers: markers,
      polylines: polylines,
      style: _mapStyle,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: onMapCreated,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (fill)
          map
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: map,
          ),
        if (etaLabel != null)
          Positioned(
            left: AppDimensions.md,
            top: AppDimensions.md,
            child: _EtaPill(
              etaLabel: etaLabel!,
              distanceLabel: distanceLabel,
              durationLabel: durationLabel,
            ),
          ),
      ],
    );
  }
}

/// Clean branded pill: arrival time as the headline, with an optional
/// distance / duration route summary underneath.
class _EtaPill extends StatelessWidget {
  const _EtaPill({
    required this.etaLabel,
    this.distanceLabel,
    this.durationLabel,
  });

  final String etaLabel;
  final String? distanceLabel;
  final String? durationLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final summaryParts = <String>[
      if (durationLabel != null) durationLabel!,
      if (distanceLabel != null) distanceLabel!,
    ];
    final summary = summaryParts.join('  ·  ');

    return Semantics(
      label: summary.isEmpty
          ? 'Chegada prevista às $etaLabel'
          : 'Chegada prevista às $etaLabel, $summary',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.xs),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chegada prevista',
                  style: text.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  etaLabel,
                  style: text.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (summary.isNotEmpty)
                  Text(
                    summary,
                    style: text.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
