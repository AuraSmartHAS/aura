import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';

/// Map showing the logistics geography: home / node / delivery / technician
/// markers plus the route polyline and ETA (spec 07: `MapPanel`).
///
/// Decoupled from feature domain — callers pass plain [LatLng] points.
class MapPanel extends StatelessWidget {
  const MapPanel({
    super.key,
    required this.home,
    this.node,
    this.delivery,
    this.technician,
    this.route = const [],
    this.etaLabel,
  });

  final LatLng home;
  final LatLng? node;
  final LatLng? delivery;
  final LatLng? technician;
  final List<LatLng> route;
  final String? etaLabel;

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
      if (route.length >= 2)
        Polyline(
          polylineId: const PolylineId('route'),
          points: route,
          color: AppColors.primary,
          width: 4,
        ),
    };

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: home, zoom: 13),
            markers: markers,
            polylines: polylines,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
        ),
        if (etaLabel != null)
          Positioned(
            left: AppDimensions.sm,
            top: AppDimensions.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.sm,
                vertical: AppDimensions.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Text(
                'ETA: $etaLabel',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
      ],
    );
  }
}
