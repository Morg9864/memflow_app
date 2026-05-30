import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/auth_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/collections/collection_detail_screen.dart';
import '../features/collections/deck_cards_screen.dart';
import '../features/home/home_screen.dart';
import '../features/import/import_screen.dart';
import '../features/legal/legal_document_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/study/session_summary_screen.dart';
import '../features/study/study_screen.dart';
import '../domain/models/models.dart';
import 'providers.dart';

/// Bridges a [Stream] to a [Listenable] so go_router re-evaluates [redirect]
/// whenever the auth state changes.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.listen((authState) {
      _isRecovery = authState.event == AuthChangeEvent.passwordRecovery;
      notifyListeners();
    });
  }

  bool _isRecovery = false;
  bool get isRecovery => _isRecovery;

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  final refresh =
      authService == null ? null : _AuthRefreshNotifier(authService.onAuthStateChange);
  if (refresh != null) {
    ref.onDispose(refresh.dispose);
  }

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      // No Supabase configured → purely local mode, no gate.
      if (authService == null) {
        return null;
      }
      final loggedIn = authService.currentSession != null;
      final atAuth = state.matchedLocation == '/auth';
      final atReset = state.matchedLocation == '/reset-password';

      // Password recovery link clicked → send to reset screen.
      if (refresh?.isRecovery == true) {
        return atReset ? null : '/reset-password';
      }

      if (!loggedIn) {
        return atAuth ? null : '/auth';
      }
      if (atAuth || atReset) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/collection/:collectionId',
        builder: (context, state) => CollectionDetailScreen(
          collectionId: state.pathParameters['collectionId']!,
        ),
      ),
      GoRoute(
        path: '/study',
        builder: (context, state) => StudyScreen(
          collectionId: state.uri.queryParameters['collectionId'],
          deckId: state.uri.queryParameters['deckId'],
        ),
      ),
      GoRoute(
        path: '/study/:deckId',
        builder: (context, state) => StudyScreen(
          deckId: state.pathParameters['deckId'],
        ),
      ),
      GoRoute(
        path: '/stats',
        builder: (context, state) => const StatisticsScreen(),
      ),
      GoRoute(
        path: '/import',
        builder: (context, state) => const ImportScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/deck/:deckId/cards',
        builder: (context, state) => DeckCardsScreen(
          deckId: state.pathParameters['deckId']!,
          deckName: state.uri.queryParameters['name'] ?? 'Deck',
        ),
      ),
      GoRoute(
        path: '/legal/:doc',
        builder: (context, state) => LegalDocumentScreen(
          document: LegalDocument.fromSlug(state.pathParameters['doc']!),
        ),
      ),
      GoRoute(
        path: '/session-summary',
        builder: (context, state) => SessionSummaryScreen(
          summary: state.extra! as SessionSummary,
        ),
      ),
    ],
  );
});
