import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'app_scaffold_messenger.dart';
import 'providers.dart';
import 'router.dart';

class MemFlowApp extends ConsumerWidget {
  const MemFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Maintient la base locale rattachée au compte connecté pendant toute la
    // vie de l'application.
    ref.watch(sessionSyncProvider);

    return MaterialApp.router(
      title: 'MemFlow',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      builder: (context, child) =>
          AdaptiveTheme(child: child ?? const SizedBox.shrink()),
      routerConfig: router,
    );
  }
}
