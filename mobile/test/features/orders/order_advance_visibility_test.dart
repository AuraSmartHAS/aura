import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/user_role.dart';
import 'package:aura/features/orders/domain/entities/order_detail.dart';
import 'package:aura/features/orders/domain/repositories/orders_repository.dart';
import 'package:aura/features/orders/domain/usecases/advance_order_usecase.dart';
import 'package:aura/features/orders/domain/usecases/get_order_usecase.dart';
import 'package:aura/features/orders/presentation/bloc/order_tracking_bloc.dart';
import 'package:aura/features/orders/presentation/widgets/order_detail_body.dart';
import 'package:aura/shared/models/order_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Avançar etapa" move a cadeia logística, e o backend só aceita o admin
/// (403 para os demais). A tela não deve oferecer uma ação que sempre falha.
class _FakeOrders implements OrdersRepository {
  @override
  Future<Result<OrderDetail>> getOrder(String orderId) async => Success(
        OrderDetail(
          orderId: orderId,
          stage: OrderStage.approved,
          deliveryStatus: 'approved',
        ),
      );

  @override
  Future<Result<List<OrderSummary>>> getHomeOrders(String homeId) async =>
      const Success([]);

  @override
  Future<Result<OrderDetail>> advance(String orderId) => getOrder(orderId);
}

Future<void> _pump(WidgetTester tester, {required bool canAdvance}) async {
  final repository = _FakeOrders();
  final bloc = OrderTrackingBloc(
    getOrderUseCase: GetOrderUseCase(repository),
    advanceOrderUseCase: AdvanceOrderUseCase(repository),
  )..add(const LoadOrderEvent('pedido-1'));
  addTearDown(bloc.close);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<OrderTrackingBloc>.value(
        value: bloc,
        child: OrderDetailBody(orderId: 'pedido-1', canAdvance: canAdvance),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  testWidgets('admin vê o controle "Avançar etapa"', (tester) async {
    await _pump(tester, canAdvance: true);

    expect(find.text('Avançar etapa (demo)'), findsOneWidget);
  });

  testWidgets('quem não é admin não vê o controle', (tester) async {
    await _pump(tester, canAdvance: false);

    expect(find.text('Etapas da entrega'), findsOneWidget);
    expect(find.text('Avançar etapa (demo)'), findsNothing);
    expect(find.text('Controle de demonstração'), findsNothing);
  });

  test('só o papel admin pode avançar pedidos', () {
    expect(UserRole.admin.canAdvanceOrders, isTrue);
    expect(UserRole.cuidadora.canAdvanceOrders, isFalse);
    expect(UserRole.paciente.canAdvanceOrders, isFalse);
    expect(UserRole.profissional.canAdvanceOrders, isFalse);
  });
}
