import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_bootstrap.dart';
import 'app/memflow_app.dart';
import 'app/providers.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await AppBootstrap.initialize();

  if (!bootstrap.environment.hasSupabase) {
    throw StateError('SUPABASE_URL et SUPABASE_ANON_KEY doivent être définis.');
  }

  await Supabase.initialize(
    url: bootstrap.environment.supabaseUrl,
    anonKey: bootstrap.environment.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(bootstrap.preferences),
        appEnvironmentProvider.overrideWithValue(bootstrap.environment),
      ],
      child: const MemFlowApp(),
    ),
  );
}
