import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/shared/models/severity_level.dart';
import 'package:aura/shared/widgets/severity_chip.dart';

void main() {
  testWidgets('SeverityChip renders the high-risk label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SeverityChip(level: SeverityLevel.high),
        ),
      ),
    );

    expect(find.text('Risco alto'), findsOneWidget);
  });
}
