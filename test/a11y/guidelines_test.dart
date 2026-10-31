// Flutter's built-in accessibility guidelines on every screen and study mode,
// before and after answering, at 360x800. Contrast reads rendered pixels, so
// the bundled fonts are loaded.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memflow/features/auth/auth_widgets.dart';
import 'package:memflow/theme/app_theme.dart';

import '../support/screen_cases.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  testWidgets('error messages and field errors meet text contrast', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                AuthErrorText('Email ou mot de passe incorrect.'),
                // Keeps the field's red border out of the row's sampled pixels.
                SizedBox(height: 32),
                TextField(
                  decoration: InputDecoration(errorText: 'Email invalide.'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    h.dispose();
  });

  testWidgets('canary: the contrast check really fails on orange text', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: Text(
                'Orange',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final result = await textContrastGuideline.evaluate(tester);
    expect(result.passed, isFalse);
    h.dispose();
  });

  for (final c in screenCases()) {
    group(c.name, () {
      Future<SemanticsHandle> open(
        WidgetTester tester, {
        Size size = const Size(360, 800),
      }) async {
        final handle = tester.ensureSemantics();
        await pumpCase(tester, c, size: size);
        if (c.interact != null) {
          await c.interact!(tester, false);
          for (var i = 0; i < 15; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        // Guards against a silently failed interaction testing the wrong state.
        if (c.interact != null) {
          expect(
            c.main(false),
            findsWidgets,
            reason: 'wrong state for ${c.name}',
          );
        }
        return handle;
      }

      testWidgets('tap target >= 48dp', (tester) async {
        final h = await open(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        h.dispose();
      });
      testWidgets('tappables are labelled', (tester) async {
        final h = await open(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        h.dispose();
      });
      testWidgets('text contrast', (tester) async {
        final h = await open(tester);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        h.dispose();
      });
      if (c.kind == 'screen') {
        // Lazy lists only build what is on screen: a tall viewport builds the
        // rest, so the guidelines also see content below the fold.
        testWidgets('all guidelines, tall viewport (360x2400)', (tester) async {
          final h = await open(tester, size: const Size(360, 2400));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          h.dispose();
        });
      }
    });
  }
}
