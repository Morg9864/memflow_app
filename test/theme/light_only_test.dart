import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/app/memflow_app.dart';
import 'package:memflow/app/providers.dart';
import 'package:memflow/app/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MemFlowApp stays light with stale dark pref and dark system', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'theme_preference': 'dark'});
    final preferences = await SharedPreferences.getInstance();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    ThemeData? captured;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Builder(
            builder: (context) {
              captured = Theme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          routerProvider.overrideWithValue(router),
          sessionSyncProvider.overrideWithValue(null),
        ],
        child: const MemFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.brightness, Brightness.light);
    expect(captured!.scaffoldBackgroundColor, const Color(0xFFFDF9F4));
    expect(captured!.colorScheme.primary, const Color(0xFFDE7935));
  });
}
