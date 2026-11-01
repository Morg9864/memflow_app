// Phones and tablets, normal and 2x text: no exception or overflow,
// and the main action stays reachable by scrolling. Long content where the
// fixtures have it. Asserts (unlike the opt-in visual harness), so a layout
// regression fails the build.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/domain/models/models.dart';

import '../support/screen_cases.dart';

const _viewports = <(String, Size)>[
  ('320x568', Size(320, 568)),
  ('360x800', Size(360, 800)),
  ('600x960', Size(600, 960)),
  ('880x1408', Size(880, 1408)),
  ('1408x880', Size(1408, 880)),
];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  // Taille de police système réelle de la tablette du propriétaire, polices de
  // l'app chargées: les longues réponses restent en grille 2x2.
  testWidgets('long answers keep the 2x2 grid at 880x1408 x1.15', (
    tester,
  ) async {
    final c = screenCases().firstWhere((c) => c.name == 'study qcm');
    await pumpCase(
      tester,
      c,
      size: const Size(880, 1408),
      textScale: 1.15,
      long: true,
    );
    final card = fixtureCard(TestMode.multipleChoice, long: true);
    final lefts = {
      for (final answer in [card.correctAnswer, ...card.wrongAnswers])
        tester.getTopLeft(find.text(answer)).dx,
    };
    expect(lefts.length, 2, reason: 'two columns of answers');
    expect(tester.takeException(), isNull);
  });

  for (final c in screenCases()) {
    for (final (vp, size) in _viewports) {
      for (final scale in [1.0, 1.15, 2.0]) {
        testWidgets('${c.name} @ $vp x$scale: no overflow, action reachable', (
          tester,
        ) async {
          await pumpCase(tester, c, size: size, textScale: scale, long: true);
          expect(tester.takeException(), isNull, reason: 'on first frames');
          if (c.interact != null) {
            await c.interact!(tester, true);
            for (var i = 0; i < 15; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(tester.takeException(), isNull, reason: 'after interacting');
          }
          final main = c.main(true);
          await revealing(tester, main);
          expect(
            main.first.hitTestable(),
            findsOneWidget,
            reason: 'main action is hit-testable after scrolling',
          );
          expect(tester.takeException(), isNull, reason: 'after scrolling');
        });
      }
    }
  }
}
