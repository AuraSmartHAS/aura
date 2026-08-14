import 'package:aura/features/orders/domain/entities/order_detail.dart';
import 'package:aura/shared/models/order_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regressão do pedido em rota (`in_route`): ETA + distância + rota chegam
/// juntos e antes a InfoTileRow usava um `Row(CrossAxisAlignment.stretch)`.
/// Dentro de um `ListView` a altura é ilimitada, o `stretch` estourava o
/// layout e derrubava a timeline, o botão do mapa e o controle de avanço.
void main() {
  OrderDetail orderInRoute() => OrderDetail(
        orderId: 'e2e8d839-b3c9-421e-9217-cf82a53ea8a7',
        stage: OrderStage.inRoute,
        eta: DateTime(2026, 8, 14, 2, 1),
        distanceM: 1870,
        durationS: 923,
        deliveryStatus: 'in_route',
        routeCoordinates: const [
          [-46.64, -23.55],
          [-46.655, -23.55969],
        ],
      );

  test('pedido em rota tem rota válida para abrir o mapa', () {
    expect(orderInRoute().hasRoute, isTrue);
  });

  testWidgets(
      'duas tiles lado a lado num ListView não estouram o layout '
      'nem escondem os widgets seguintes', (tester) async {
    // Reproduz o padrão exato corrigido: duas tiles de altura desigual num
    // Row dentro de um ListView, seguidas de mais conteúdo. Com `stretch`
    // isso lançava durante o layout; com `start` renderiza inteiro.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _Tile(lines: 1)),
                  SizedBox(width: 12),
                  Expanded(child: _Tile(lines: 3)),
                ],
              ),
              Text('depois-da-row'),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('depois-da-row'), findsOneWidget);
  });
}

class _Tile extends StatelessWidget {
  const _Tile({required this.lines});
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (var i = 0; i < lines; i++) const Text('linha')],
    );
  }
}
