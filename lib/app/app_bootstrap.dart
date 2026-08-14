import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/database.dart';

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
    required this.database,
  });

  final SharedPreferences preferences;
  final AppEnvironment environment;
  final AppDatabase database;

  static Future<AppBootstrap> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    const environment = AppEnvironment.fromEnvironment();

    if (!environment.hasSupabase) {
      throw StateError(
        'SUPABASE_URL et SUPABASE_ANON_KEY doivent être définis.',
      );
    }

    // Supabase restaure la session depuis le stockage local. Un démarrage sans
    // réseau ne doit pas empêcher l'application de s'ouvrir sur ses données
    // locales : on tolère l'échec et la synchronisation reprendra plus tard.
    try {
      await Supabase.initialize(
        url: environment.supabaseUrl,
        anonKey: environment.supabaseAnonKey,
      );
    } catch (_) {
      // Session non rafraîchie : l'app démarre quand même.
    }

    return AppBootstrap(
      preferences: preferences,
      environment: environment,
      database: AppDatabase(),
    );
  }
}
