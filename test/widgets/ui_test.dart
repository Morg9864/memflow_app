import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/widgets/ui.dart';

void main() {
  testWidgets('horizontal compact stat cards fit tablet constraints', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 370,
            height: 104,
            child: StatCard(
              compact: true,
              horizontal: true,
              value: '729',
              label: 'à revoir',
              icon: Icons.schedule_rounded,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('729'), findsOneWidget);
    expect(find.text('à revoir'), findsOneWidget);
  });
}
