// Host side of integration_test/perf_test.dart. Writes the raw report to
// build/perf/$PERF_RUN.json and, after the run, the app's `dumpsys meminfo`
// (the app is still alive when the callback runs).
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final env = Platform.environment;
    final run = env['PERF_RUN'] ?? 'run';
    final pkg = env['PERF_PKG'] ?? 'com.memflow.app.memflow.perf';
    final serial = env['ANDROID_SERIAL'];
    var meminfo = '';
    // Read-only, and never against the real app id.
    if (pkg.endsWith('.perf')) {
      final r = await Process.run('adb', [
        if (serial != null) ...['-s', serial],
        'shell',
        'dumpsys',
        'meminfo',
        pkg,
      ]);
      meminfo = r.stdout as String;
    }
    final dir = Directory('build/perf')..createSync(recursive: true);
    File(
      '${dir.path}/$run.json',
    ).writeAsStringSync(jsonEncode({'data': data, 'meminfo': meminfo}));
  },
);
