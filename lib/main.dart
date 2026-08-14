import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_bootstrap.dart';
import 'app/memflow_app.dart';
import 'app/providers.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await AppBootstrap.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(bootstrap.preferences),
        appEnvironmentProvider.overrideWithValue(bootstrap.environment),
        appDatabaseProvider.overrideWithValue(bootstrap.database),
      ],
      child: const MemFlowApp(),
    ),
  );
}
