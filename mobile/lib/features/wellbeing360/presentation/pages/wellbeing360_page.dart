import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../bloc/wellbeing360_bloc.dart';
import '../widgets/wellbeing360_body.dart';

class Wellbeing360Page extends StatelessWidget {
  const Wellbeing360Page({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<Wellbeing360Bloc>()..add(const LoadScoresEvent()),
      child: const Wellbeing360Body(),
    );
  }
}
