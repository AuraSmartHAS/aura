import 'package:aura/features/caregiver_dashboard/presentation/widgets/dashboard_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Defeito #4: o painel cumprimentava qualquer conta como "Ana".
void main() {
  Future<void> pumpHeader(WidgetTester tester, String? firstName) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardHeader(
              userFirstName: firstName,
              patientName: 'Maria',
              address: 'Rua A, 1',
            ),
          ),
        ),
      );

  List<String> greetings(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where(RegExp(r'^(Bom dia|Boa tarde|Boa noite)').hasMatch)
      .toList();

  testWidgets('cumprimenta pelo primeiro nome de quem está logado',
      (tester) async {
    await pumpHeader(tester, 'Beatriz');

    expect(
      greetings(tester).single,
      matches(RegExp(r'^(Bom dia|Boa tarde|Boa noite), Beatriz$')),
    );
    expect(find.textContaining('Ana'), findsNothing);
  });

  testWidgets('sem nome utilizável, só a saudação — nada de "Ana"',
      (tester) async {
    await pumpHeader(tester, null);

    expect(
      greetings(tester).single,
      matches(RegExp(r'^(Bom dia|Boa tarde|Boa noite)$')),
    );
    expect(find.textContaining('Ana'), findsNothing);
  });
}
