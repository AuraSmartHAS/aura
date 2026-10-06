import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/auth_session.dart';
import '../bloc/order_tracking_bloc.dart';
import '../widgets/order_detail_body.dart';

class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OrderTrackingBloc>()..add(LoadOrderEvent(orderId)),
      child: OrderDetailBody(
        orderId: orderId,
        canAdvance: sl<AuthSession>().role?.canAdvanceOrders ?? false,
      ),
    );
  }
}
