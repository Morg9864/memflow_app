import 'package:memflow/theme/app_icons.dart';
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
              icon: AppIcons.calendarDays,
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

  group('Pressable', () {
    double scaleOf(WidgetTester t) =>
        t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    Widget host({bool reduce = false, VoidCallback? onTap}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Center(
          child: Pressable(
            child: GestureDetector(
              onTap: onTap,
              child: const ColoredBox(
                color: Colors.red,
                key: Key('box'),
                child: SizedBox(width: 80, height: 80),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('scales on pointer down and resets on up', (tester) async {
      await tester.pumpWidget(host());
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('box'))),
      );
      await tester.pump();
      expect(scaleOf(tester), 0.98);
      await g.up();
      await tester.pump();
      expect(scaleOf(tester), 1.0);
    });

    testWidgets('does not scale under reduced motion', (tester) async {
      await tester.pumpWidget(host(reduce: true));
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('box'))),
      );
      await tester.pump();
      expect(scaleOf(tester), 1.0);
      await g.up();
    });

    testWidgets('does not block the child onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(onTap: () => taps++));
      await tester.tap(find.byKey(const Key('box')));
      expect(taps, 1);
    });
  });

  group('ProgressPill', () {
    double shown(WidgetTester t) => t
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;

    Widget host(double v, {bool reduce = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(body: ProgressPill(value: v)),
      ),
    );

    testWidgets('first build does not animate, later changes do', (
      tester,
    ) async {
      await tester.pumpWidget(host(0.5));
      expect(shown(tester), 0.5);
      await tester.pumpWidget(host(1.0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(shown(tester), allOf(greaterThan(0.5), lessThan(1.0)));
      await tester.pumpAndSettle();
      expect(shown(tester), 1.0);
    });

    testWidgets('jumps straight to the value under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(host(0.2, reduce: true));
      await tester.pumpWidget(host(0.9, reduce: true));
      await tester.pump();
      expect(shown(tester), 0.9);
    });
  });

  testWidgets('AppErrorState shows the title and calls onRetry', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppErrorState(onRetry: () => retries++)),
      ),
    );
    expect(find.text('Une erreur est survenue'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    expect(retries, 1);
  });

  testWidgets('EmptyState does not overflow at 2.0 text scale in 320 px', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: const Scaffold(
            body: SizedBox(
              width: 320,
              height: 480,
              child: SingleChildScrollView(
                child: EmptyState(
                  title: 'Aucune collection pour le moment',
                  message:
                      'Importe un fichier CSV pour créer ta première collection.',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
