import 'package:shared_preferences/shared_preferences.dart';

class AppBootstrap {
  const AppBootstrap({
    required this.preferences,
  });

  final SharedPreferences preferences;

  static Future<AppBootstrap> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    return AppBootstrap(preferences: preferences);
  }
}
