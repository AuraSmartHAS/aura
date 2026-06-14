import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/router/app_routes.dart';
import '../bloc/home_setup_bloc.dart';
import '../widgets/onboarding_body.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HomeSetupBloc>(),
      child: BlocListener<HomeSetupBloc, HomeSetupState>(
        listenWhen: (prev, curr) => curr.step == SetupStep.done,
        listener: (context, state) => context.go(AppRoutes.dashboard),
        child: const OnboardingBody(),
      ),
    );
  }
}
