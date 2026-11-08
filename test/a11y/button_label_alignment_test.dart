// A button label that wraps (large text) must be centred in its button, for
// every Material button kind, not left-aligned. ButtonStyle has no textAlign,
// so the theme centres it through foregroundBuilder.
import 'package:memflow/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/theme/app_theme.dart';

import '../support/screen_cases.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  /// Left edge of each wrapped line of the label, relative to the text box.
  List<double> lineLefts(WidgetTester tester, Finder label) {
    final paragraph = tester.renderObject<RenderParagraph>(label);
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: paragraph.text.toPlainText().length,
      ),
    );
    return boxes.map((b) => b.left).toSet().toList()..sort();
  }

  testWidgets('"Se connecter" is centred when it wraps (auth @ 320, x2.0)', (
    tester,
  ) async {
    final auth = screenCases().firstWhere((c) => c.name == 'auth');
    await pumpCase(tester, auth, size: const Size(320, 568), textScale: 2.0);
    final label = find.descendant(
      of: find.byType(FilledButton),
      matching: find.text('Se connecter'),
    );
    final lefts = lineLefts(tester, label);
    // Centred lines of different widths start at different x; left-aligned
    // ones all start at 0.
    expect(lefts.last - lefts.first, greaterThan(1));
  });

  for (final (name, build) in <(String, Widget Function(String))>[
    ('FilledButton', (t) => FilledButton(onPressed: () {}, child: Text(t))),
    (
      'FilledButton.tonal',
      (t) => FilledButton.tonal(onPressed: () {}, child: Text(t)),
    ),
    (
      'FilledButton.icon',
      (t) => FilledButton.icon(
        onPressed: () {},
        icon: const Icon(AppIcons.plus),
        label: Text(t),
      ),
    ),
    ('OutlinedButton', (t) => OutlinedButton(onPressed: () {}, child: Text(t))),
    ('TextButton', (t) => TextButton(onPressed: () {}, child: Text(t))),
  ]) {
    testWidgets('$name centres a wrapped label', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(200, 600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 150,
                child: build('Un libellé assez long pour passer à la ligne'),
              ),
            ),
          ),
        ),
      );
      final label = find.textContaining('Un libellé');
      expect(
        DefaultTextStyle.of(tester.element(label)).textAlign,
        TextAlign.center,
      );
    });
  }
}
