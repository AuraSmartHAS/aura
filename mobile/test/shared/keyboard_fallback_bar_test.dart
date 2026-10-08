import 'package:aura/shared/widgets/keyboard_fallback_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<FallbackAction> actions,
      {double textScale = 1.0}) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: KeyboardFallbackBar(actions: actions),
          ),
        ),
      ),
    ));
  }

  final digitar =
      FallbackAction(label: 'Prefiro digitar', icon: Icons.keyboard, onTap: () {});
  final ouvir =
      FallbackAction(label: 'Ouvir de novo', icon: Icons.replay, onTap: () {});

  testWidgets('"Prefiro digitar" e "Ouvir de novo" ficam lado a lado, da mesma altura',
      (tester) async {
    await pump(tester, [digitar, ouvir]);

    final a = tester.getRect(find.ancestor(
        of: find.text('Prefiro digitar'), matching: find.byType(InkWell)));
    final b = tester.getRect(find.ancestor(
        of: find.text('Ouvir de novo'), matching: find.byType(InkWell)));

    expect(a.top, b.top);
    expect(a.height, b.height);
    expect(a.right, lessThan(b.left));
  });

  testWidgets('com a fonte grande o rótulo quebra, mas os dois seguem iguais e sem estourar',
      (tester) async {
    await pump(tester, [digitar, ouvir], textScale: 1.3);

    final a = tester.getRect(find.ancestor(
        of: find.text('Prefiro digitar'), matching: find.byType(InkWell)));
    final b = tester.getRect(find.ancestor(
        of: find.text('Ouvir de novo'), matching: find.byType(InkWell)));
    expect(a.height, b.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sozinho, "Prefiro digitar" ocupa a largura toda', (tester) async {
    await pump(tester, [digitar]);

    final botao = tester.getRect(find.ancestor(
        of: find.text('Prefiro digitar'), matching: find.byType(InkWell)));
    expect(botao.width, closeTo(800 - 48, 1));
  });
}
