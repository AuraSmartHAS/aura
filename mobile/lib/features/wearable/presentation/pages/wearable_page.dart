import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../bloc/wearable_bloc.dart';
import '../widgets/wearable_body.dart';

class WearablePage extends StatelessWidget {
  const WearablePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<WearableBloc>(),
      child: const WearableBody(),
    );
  }
}
