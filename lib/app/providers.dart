import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_bootstrap.dart';
import '../data/local/database.dart';
import '../data/repositories/app_repository.dart';
import '../data/sync/sync_service.dart';
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

/// Base locale : source de vérité pour tout ce qui est affiché. Elle est
/// fournie par le bootstrap pour que son ouverture, asynchrone, soit terminée
/// avant le premier écran.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('AppDatabase must be overridden during bootstrap.');
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    database: ref.watch(appDatabaseProvider),
    client: ref.watch(supabaseClientProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.statusStream;
});

final appRepositoryProvider = Provider<AppRepository>((ref) {
  return AppRepository(
    database: ref.watch(appDatabaseProvider),
    syncService: ref.watch(syncServiceProvider),
    spacedRepetitionService: ref.watch(spacedRepetitionServiceProvider),
    cardModeService: ref.watch(cardModeServiceProvider),
  );
});

/// Rattache la base locale au compte connecté : elle est adoptée et
/// synchronisée à la connexion, purgée à la déconnexion.
final sessionSyncProvider = Provider<void>((ref) {
  final service = ref.watch(syncServiceProvider);
  String? boundUserId;
  var initialized = false;

  void bind(String? userId) {
    if (initialized && userId == boundUserId) {
      return;
    }
    initialized = true;
    boundUserId = userId;
    if (userId == null) {
      unawaited(service.stopAndClear());
    } else {
      unawaited(service.startFor(userId));
    }
  }

  bind(ref.read(authServiceProvider).currentUser?.id);
  ref.listen(currentUserProvider, (previous, next) => bind(next?.id));
});
