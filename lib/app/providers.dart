import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_bootstrap.dart';
import '../data/repositories/app_repository.dart';
import '../domain/services/auth_service.dart';
import '../domain/services/card_mode_service.dart';
import '../domain/services/csv_export_service.dart';
import '../domain/services/csv_import_service.dart';
import '../domain/services/spaced_repetition_service.dart';

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  throw UnimplementedError(
    'AppEnvironment must be overridden during bootstrap.',
  );
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  if (!environment.hasSupabase) {
    throw StateError('SUPABASE_URL et SUPABASE_ANON_KEY sont requis.');
  }
  return Supabase.instance.client;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authServiceProvider).currentUser;
});

final displayNameProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return null;
  }
  final name = user.userMetadata?['display_name'] as String?;
  if (name != null && name.trim().isNotEmpty) {
    return name.trim();
  }
  return user.email?.split('@').first;
});

final spacedRepetitionServiceProvider = Provider<SpacedRepetitionService>(
  (ref) => const SpacedRepetitionService(),
);

final cardModeServiceProvider = Provider<CardModeService>(
  (ref) => const CardModeService(),
);

final csvImportServiceProvider = Provider<CsvImportService>((ref) {
  return CsvImportService(ref.watch(cardModeServiceProvider));
});

final csvExportServiceProvider = Provider<CsvExportService>(
  (ref) => const CsvExportService(),
);

class AppDataRevisionController extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final appDataRevisionProvider =
    NotifierProvider<AppDataRevisionController, int>(
      AppDataRevisionController.new,
    );

final appRepositoryProvider = Provider<AppRepository>((ref) {
  ref.watch(appDataRevisionProvider);
  final revisionNotifier = ref.read(appDataRevisionProvider.notifier);
  return AppRepository(
    client: ref.watch(supabaseClientProvider),
    spacedRepetitionService: ref.watch(spacedRepetitionServiceProvider),
    cardModeService: ref.watch(cardModeServiceProvider),
    onDataChanged: () {
      if (!ref.mounted) {
        return;
      }
      revisionNotifier.bump();
    },
  );
});

final appInitializationProvider = FutureProvider<void>((ref) async {
  ref.watch(supabaseClientProvider);
});
