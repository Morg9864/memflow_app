import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/app/router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('waits for the first auth event before resolving routing', () async {
    final events = StreamController<AuthState>();
    final notifier = AuthRefreshNotifier(events.stream);
    addTearDown(() async {
      notifier.dispose();
      await events.close();
    });

    expect(notifier.hasResolvedAuthState, isFalse);

    events.add(AuthState(AuthChangeEvent.initialSession, null));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.hasResolvedAuthState, isTrue);
    expect(notifier.isRecovery, isFalse);
  });

  test('marks password recovery without treating it as a signed-out state',
      () async {
    final events = StreamController<AuthState>();
    final notifier = AuthRefreshNotifier(events.stream);
    addTearDown(() async {
      notifier.dispose();
      await events.close();
    });

    events.add(AuthState(AuthChangeEvent.passwordRecovery, null));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.hasResolvedAuthState, isTrue);
    expect(notifier.isRecovery, isTrue);
  });
}
