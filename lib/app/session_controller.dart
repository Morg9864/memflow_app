import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/database.dart';
import '../data/repositories/app_repository.dart';
import '../domain/services/sync_service.dart';

/// Meta key tracking which account currently owns the local Drift database.
const String kActiveUserIdKey = 'active_user_id';

/// Reconciles the local-first Drift database with the signed-in Supabase
/// account. Listens to GoTrue auth events and, on sign-in, either claims
/// pre-existing anonymous data, resumes the same account, or wipes and pulls a
/// different account's data. On sign-out it clears local user data.
class SessionController {
  SessionController({
    required AppDatabase database,
    required AppRepository repository,
    required SyncService syncService,
    required Stream<AuthState> authStateChanges,
  })  : _database = database,
        _repository = repository,
        _syncService = syncService {
    _subscription = authStateChanges.listen(_handleAuthState);
  }

  final AppDatabase _database;
  final AppRepository _repository;
  final SyncService _syncService;

  StreamSubscription<AuthState>? _subscription;

  // Serializes reconciliation so overlapping auth events don't race.
  Future<void> _pending = Future<void>.value();

  void _handleAuthState(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
        final user = state.session?.user;
        if (user != null) {
          _enqueue(() => reconcileSignIn(user.id));
        }
      case AuthChangeEvent.signedOut:
        _enqueue(reconcileSignOut);
      default:
        // tokenRefreshed / userUpdated / passwordRecovery: nothing to sync.
        break;
    }
  }

  void _enqueue(Future<void> Function() action) {
    _pending = _pending.then((_) => action()).catchError((_) {});
  }

  /// Reconciles local data when [userId] signs in. Public for testing; normally
  /// driven by the auth event stream.
  Future<void> reconcileSignIn(String userId) async {
    final activeUserId = await _database.readMetaString(kActiveUserIdKey);

    if (activeUserId == userId) {
      // Same account resuming on this device: just sync.
      await _syncService.runSync();
      return;
    }

    if (activeUserId == null) {
      // First account to claim this device. Keep any anonymous local data and
      // push it up so it becomes owned by this user.
      final hasLocalData = !(await _database.isEmpty());
      await _database.writeMetaString(kActiveUserIdKey, userId);
      if (hasLocalData) {
        await _repository.enqueueAllLocalEntities();
      }
      await _syncService.runSync();
      await _repository.refreshAllDerivedData();
      return;
    }

    // A different account signed in: drop the previous user's local data and
    // pull this account's data fresh. clearAllUserData() also clears the meta
    // table, so write the active user afterwards.
    await _database.clearAllUserData();
    await _database.writeMetaString(kActiveUserIdKey, userId);
    await _syncService.runSync();
    await _repository.refreshAllDerivedData();
  }

  /// Clears local user data on sign-out. Public for testing.
  Future<void> reconcileSignOut() async {
    await _database.clearAllUserData();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
