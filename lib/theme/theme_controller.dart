import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/models.dart';

class ThemeController extends Notifier<ThemePreference> {
  static const _key = 'theme_preference';

  @override
  ThemePreference build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    return ThemePreference.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => ThemePreference.system,
    );
  }

  Future<void> setPreference(ThemePreference preference) async {
    state = preference;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, preference.name);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences override is missing.');
});

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemePreference>(ThemeController.new);
