import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_controller.dart';

class DailyGoalController extends Notifier<int> {
  static const _key = 'daily_goal';
  static const _defaultGoal = 20;

  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getInt(_key) ?? _defaultGoal;
  }

  Future<void> setGoal(int goal) async {
    final clamped = goal.clamp(1, 999);
    state = clamped;
    await ref.read(sharedPreferencesProvider).setInt(_key, clamped);
  }
}

final dailyGoalProvider = NotifierProvider<DailyGoalController, int>(DailyGoalController.new);
