import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/widgets/ui.dart';

void main() {
  // Pressing a list row, then scrolling it off-screen, disposes it mid-press.
  testWidgets('releasing after the widget is disposed does not throw', (
    tester,
  ) async {
    Widget app({required bool show}) => MaterialApp(
      home: Scaffold(
        body: show
            ? Pressable(
                child: Container(
                  key: const Key('p'),
                  width: 100,
                  height: 100,
                  color: Colors.white,
                ),
              )
            : const SizedBox(),
      ),
    );
    await tester.pumpWidget(app(show: true));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('p'))),
    );
    await tester.pump();
    await tester.pumpWidget(app(show: false));
    await gesture.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
