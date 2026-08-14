import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/models.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'app_scaffold_messenger.dart';
import 'providers.dart';
import 'router.dart';

class MemFlowApp extends ConsumerWidget {
  const MemFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePreference = ref.watch(themeControllerProvider);
    final router = ref.watch(routerProvider);
    // Maintient la base locale rattachée au compte connecté pendant toute la
    // vie de l'application.
    ref.watch(sessionSyncProvider);

    return MaterialApp.router(
      title: 'MemFlow',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: themePreference == ThemePreference.vivid
          ? AppTheme.vivid()
          : AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themePreference.themeMode,
      routerConfig: router,
      builder: (context, child) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
