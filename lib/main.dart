import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_bootstrap.dart';
import 'app/memflow_app.dart';
import 'app/providers.dart';

Future<void> main() async {
  await _runGuarded();
}

/// Report uncaught errors to the local runtime surfaces only.
Future<void> _runGuarded() async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Uncaught Flutter error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error\n$stack');
    return true;
  };

  await runZonedGuarded(_bootstrapAndRun, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

Future<void> _bootstrapAndRun() async {
  WidgetsFlutterBinding.ensureInitialized();
  for (final family in const ['Lora', 'Outfit']) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/fonts/OFL-$family.txt'));
    });
  }
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
