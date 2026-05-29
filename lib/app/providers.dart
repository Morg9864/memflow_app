import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_bootstrap.dart';
import 'session_controller.dart';
import '../data/local/database.dart';
import '../data/repositories/app_repository.dart';
import '../domain/services/auth_service.dart';
import '../domain/services/card_mode_service.dart';
import '../domain/services/csv_export_service.dart';
import '../domain/services/csv_import_service.dart';
import '../domain/services/spaced_repetition_service.dart';
import '../domain/services/sync_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  throw UnimplementedError('AppEnvironment must be overridden during bootstrap.');
});

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  final environment = ref.watch(appEnvironmentProvider);

  if (!environment.hasSupabase) {
    return null;
  }

  // Supabase.initialize() is called during bootstrap (see main.dart), so the
  // shared client with persisted GoTrue session is reused here.
  return Supabase.instance.client;
});

final authServiceProvider = Provider<AuthService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return AuthService(client);
});

/// Emits GoTrue auth events (sign in, sign out, token refresh). Stays in the
/// loading state when Supabase is not configured.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  if (authService == null) {
    return const Stream<AuthState>.empty();
  }
  return authService.onAuthStateChange;
});

/// The currently authenticated user, or null when signed out / not configured.
final currentUserProvider = Provider<User?>((ref) {
  // Re-read on every auth event so dependents rebuild on sign in/out.
  ref.watch(authStateProvider);
  return ref.watch(authServiceProvider)?.currentUser;
});

/// The user's chosen display name (from sign-up), falling back to the local
/// part of their email, then null when signed out.
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

final spacedRepetitionServiceProvider =
    Provider<SpacedRepetitionService>((ref) => const SpacedRepetitionService());

final cardModeServiceProvider =
    Provider<CardModeService>((ref) => const CardModeService());

final csvImportServiceProvider = Provider<CsvImportService>((ref) {
  return CsvImportService(ref.watch(cardModeServiceProvider));
});

final csvExportServiceProvider =
    Provider<CsvExportService>((ref) => const CsvExportService());

final syncRemoteSourceProvider = Provider<SyncRemoteSource?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return SupabaseSyncRemoteSource(client);
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    database: ref.watch(appDatabaseProvider),
    remoteSource: ref.watch(syncRemoteSourceProvider),
  );
});

final appRepositoryProvider = Provider<AppRepository>((ref) {
  return AppRepository(
    database: ref.watch(appDatabaseProvider),
    spacedRepetitionService: ref.watch(spacedRepetitionServiceProvider),
    cardModeService: ref.watch(cardModeServiceProvider),
    syncService: ref.watch(syncServiceProvider),
  );
});

/// Reconciles the local database with the signed-in account on auth changes.
/// Null when Supabase is not configured (purely local mode).
final sessionControllerProvider = Provider<SessionController?>((ref) {
  final authService = ref.watch(authServiceProvider);
  if (authService == null) {
    return null;
  }
  final controller = SessionController(
    database: ref.watch(appDatabaseProvider),
    repository: ref.watch(appRepositoryProvider),
    syncService: ref.watch(syncServiceProvider),
    authStateChanges: authService.onAuthStateChange,
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final appInitializationProvider = FutureProvider<void>((ref) async {
  // Start auth-driven reconciliation (claim / switch / sync). Syncing is now
  // owned by the session controller and only runs once authenticated.
  ref.watch(sessionControllerProvider);
  await ref.read(appRepositoryProvider).refreshAllDerivedData();
});
