import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/router/app_router.dart';
import '../bloc/consent_bloc.dart';
import '../widgets/consent_body.dart';

class ConsentPage extends StatelessWidget {
  const ConsentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ConsentBloc>(),
      child: BlocListener<ConsentBloc, ConsentState>(
        listener: (context, state) {
          if (state is ConsentAccepted) {
            // Land on the role-appropriate surface (patient → voice,
            // caregiver → dashboard/onboarding).
            context.go(AppRouter.homeForRole());
          } else if (state is ConsentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: const ConsentBody(),
      ),
    );
  }
}
