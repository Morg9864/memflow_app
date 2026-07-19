import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:memflow/theme/theme_controller.dart';
import 'package:memflow/widgets/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('vivid exposes the expected color scheme', () {
    const scheme = AppTheme.vividColorScheme;

    expect(scheme.brightness, Brightness.light);
    expect(AppColors.backgroundVivid, const Color(0xFFF5FBFF));
    expect(scheme.primary, const Color(0xFF245BFF));
    expect(scheme.secondary, const Color(0xFFE03F8F));
    expect(scheme.tertiary, const Color(0xFF00A887));
    expect(scheme.onSurface, const Color(0xFF101828));
    expect(scheme.outlineVariant, const Color(0xFFB8C6E3));
    expect(scheme.error, const Color(0xFFD92D20));
  });

  testWidgets('theme menu lists and persists vivid', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: AppTheme.vividColorScheme,
          ),
          home: const Scaffold(body: ThemeToggleButton()),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();

    for (final preference in ThemePreference.values) {
      expect(find.text(preference.label), findsOneWidget);
    }

    await tester.tap(find.text('Vivid'));
    await tester.pumpAndSettle();

    expect(container.read(themeControllerProvider), ThemePreference.vivid);
    expect(preferences.getString('theme_preference'), 'vivid');
  });
}
