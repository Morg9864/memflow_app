import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_bootstrap.dart';
import '../data/local/database.dart';
import '../data/repositories/app_repository.dart';
import '../domain/services/card_mode_service.dart';
import '../domain/services/csv_export_service.dart';
import '../domain/services/csv_import_service.dart';
import '../domain/services/mock_seed_service.dart';
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

  return SupabaseClient(
    environment.supabaseUrl,
    environment.supabaseAnonKey,
  );
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

final mockSeedServiceProvider = Provider<MockSeedService>((ref) {
  return MockSeedService(
    database: ref.watch(appDatabaseProvider),
    cardModeService: ref.watch(cardModeServiceProvider),
  );
});

final appInitializationProvider = FutureProvider<void>((ref) async {
  final syncService = ref.read(syncServiceProvider);
  if (syncService.isEnabled) {
    await syncService.runSync();
  } else {
    await ref.read(mockSeedServiceProvider).seedIfNeeded();
  }
  await ref.read(appRepositoryProvider).refreshAllDerivedData();
});
