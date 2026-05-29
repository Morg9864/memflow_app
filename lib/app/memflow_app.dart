import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/models.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'providers.dart';
import 'router.dart';

class MemFlowApp extends ConsumerWidget {
  const MemFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePreference = ref.watch(themeControllerProvider);
    final router = ref.watch(routerProvider);
    final initialization = ref.watch(appInitializationProvider);

    return MaterialApp.router(
      title: 'MemFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themePreference.themeMode,
      routerConfig: router,
      builder: (context, child) {
        return initialization.when(
          data: (_) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: child ?? const SizedBox.shrink(),
          ),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Scaffold(
            body: Center(child: Text(error.toString())),
          ),
        );
      },
    );
  }
}
