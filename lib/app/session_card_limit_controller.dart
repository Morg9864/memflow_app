import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_controller.dart';

class SessionCardLimitController extends Notifier<int> {
  static const _key = 'session_card_limit';
  static const _defaultLimit = 12;

  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getInt(_key) ?? _defaultLimit;
  }

  Future<void> setLimit(int limit) async {
    final clamped = limit.clamp(1, 999);
    state = clamped;
    await ref.read(sharedPreferencesProvider).setInt(_key, clamped);
  }
}

final sessionCardLimitProvider =
    NotifierProvider<SessionCardLimitController, int>(
      SessionCardLimitController.new,
    );
