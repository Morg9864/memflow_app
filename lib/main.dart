import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/app_bootstrap.dart';
import 'app/memflow_app.dart';
import 'app/providers.dart';
import 'theme/theme_controller.dart';

/// Optional: without it the app still runs, but crashes are only visible
/// locally (see [_runGuarded]) instead of being reported remotely.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  if (_sentryDsn.isEmpty) {
    await _runGuarded();
    return;
  }

  await SentryFlutter.init(
    (options) => options
      ..dsn = _sentryDsn
      ..environment = kReleaseMode ? 'production' : 'development'
      ..tracesSampleRate = 0.2,
    appRunner: _bootstrapAndRun,
  );
}

/// No Sentry DSN configured: still make sure nothing crashes silently by
/// wiring the same error surfaces Sentry would otherwise cover.
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
