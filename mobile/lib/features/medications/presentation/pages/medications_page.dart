import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../bloc/medication_bloc.dart';
import '../widgets/medications_body.dart';

class MedicationsPage extends StatelessWidget {
  const MedicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MedicationBloc>()..add(const LoadMedicationsEvent()),
      child: const MedicationsBody(),
    );
  }
}
