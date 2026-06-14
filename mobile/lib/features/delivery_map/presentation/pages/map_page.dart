import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../bloc/map_bloc.dart';
import '../widgets/map_body.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MapBloc>()..add(LoadMapEvent(orderId)),
      child: const MapBody(),
    );
  }
}
