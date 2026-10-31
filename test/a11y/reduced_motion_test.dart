// With disableAnimations, nothing may keep animating: after a few zero-time
// pump()s there is no scheduled frame left, with no pumpAndSettle needed.
import 'package:flutter_test/flutter_test.dart';

import '../support/screen_cases.dart';

const _maxPumps = 6;

/// Pumps without advancing the clock until no frame is scheduled.
Future<int> settleWithoutTime(WidgetTester tester) async {
  // One pump first: async work (a load, a save) only schedules its frame
  // once its microtasks have run.
  await tester.pump();
  var n = 1;
  while (tester.binding.hasScheduledFrame && n < _maxPumps) {
    await tester.pump();
    n++;
  }
  return n;
}

void expectIdle(WidgetTester tester, String what) {
  expect(tester.takeException(), isNull, reason: what);
  expect(
    tester.binding.hasScheduledFrame,
    isFalse,
    reason:
        '$what: a frame is still scheduled after $_maxPumps zero-time '
        'pumps (something keeps animating under reduced motion)',
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  for (final c in screenCases().where((c) => c.interact == null)) {
    testWidgets('${c.name} is idle under reduced motion', (tester) async {
      await pumpCase(tester, c, disableAnimations: true, warmUp: false);
      await settleWithoutTime(tester);
      expectIdle(tester, c.name);
    });
  }

  group('study flow', () {
    final qcm = screenCases().firstWhere((c) => c.name == 'study qcm');

    testWidgets('answering a QCM question, then the next card', (tester) async {
      // Taps go through semantics: a pointer tap starts an ink ripple, which
      // is framework-owned and runs ~0.3s whatever the reduced-motion flag.
      final handle = tester.ensureSemantics();
      await pumpCase(tester, qcm, disableAnimations: true, warmUp: false);
      await settleWithoutTime(tester);
      expectIdle(tester, 'QCM question');

      tester.semantics.tap(find.semantics.byLabel(RegExp('ribosome')));
      await settleWithoutTime(tester);
      expectIdle(tester, 'QCM answered');
      expect(find.text('Encore'), findsOneWidget);

      tester.semantics.tap(find.semantics.byLabel(RegExp('^Encore')));
      await settleWithoutTime(tester);
      expectIdle(tester, 'next card');
      expect(
        find.text('2/2'),
        findsOneWidget,
        reason: 'moved to the next card',
      );
      handle.dispose();
    });

    for (final name in [
      'study flashcard front',
      'study true/false',
      'study free text',
      'study cloze',
    ]) {
      final c = screenCases().firstWhere((c) => c.name == name);
      testWidgets('$name is idle under reduced motion', (tester) async {
        await pumpCase(tester, c, disableAnimations: true, warmUp: false);
        await settleWithoutTime(tester);
        expectIdle(tester, name);
      });
    }
  });
}
