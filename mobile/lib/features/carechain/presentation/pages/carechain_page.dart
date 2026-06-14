import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/router/app_routes.dart';
import '../bloc/carechain_bloc.dart';
import '../widgets/carechain_body.dart';

class CareChainPage extends StatelessWidget {
  const CareChainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CareChainBloc>()..add(const LoadRecommendationEvent()),
      child: BlocListener<CareChainBloc, CareChainState>(
        listenWhen: (prev, curr) =>
            prev.approvedOrderId != curr.approvedOrderId &&
            curr.approvedOrderId != null,
        listener: (context, state) {
          // RN-022: approval created the order → open its tracker.
          context.go(AppRoutes.orderDetail(state.approvedOrderId!));
        },
        child: const CareChainBody(),
      ),
    );
  }
}
