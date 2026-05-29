import 'package:shared_preferences/shared_preferences.dart';

class AppEnvironment {
  const AppEnvironment({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  const AppEnvironment.fromEnvironment()
      : supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

class AppBootstrap {
  const AppBootstrap({
    required this.preferences,
    required this.environment,
  });

  final SharedPreferences preferences;
  final AppEnvironment environment;

  static Future<AppBootstrap> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    return AppBootstrap(
      preferences: preferences,
      environment: const AppEnvironment.fromEnvironment(),
    );
  }
}
