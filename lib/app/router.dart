import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/auth_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/collections/collection_detail_screen.dart';
import '../features/collections/collection_due_cards_screen.dart';
import '../features/collections/deck_cards_screen.dart';
import '../features/home/home_screen.dart';
import '../features/import/import_screen.dart';
import '../features/legal/legal_document_screen.dart';
import '../features/navigation/not_found_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/study/session_summary_screen.dart';
import '../features/study/study_screen.dart';
import '../domain/models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'providers.dart';

/// Bridges a [Stream] to a [Listenable] so go_router re-evaluates [redirect]
/// whenever the auth state changes.
class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier(Stream<AuthState> stream) {
    _subscription = stream.listen((authState) {
      _hasResolvedAuthState = true;
      _isRecovery = authState.event == AuthChangeEvent.passwordRecovery;
      notifyListeners();
    });
  }

  bool _isRecovery = false;
  bool get isRecovery => _isRecovery;

  bool _hasResolvedAuthState = false;
  bool get hasResolvedAuthState => _hasResolvedAuthState;

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  final refresh = AuthRefreshNotifier(authService.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    errorBuilder: (context, state) =>
        NotFoundScreen(requestedPath: state.uri.toString()),
    redirect: (context, state) {
      // Supabase emits the locally restored session through this stream. Do
      // not route to /auth during the small window before that first event.
      if (!refresh.hasResolvedAuthState) {
        return null;
      }

      final loggedIn = authService.currentSession != null;
      final atAuth = state.matchedLocation == '/auth';
      final atReset = state.matchedLocation == '/reset-password';

      // Password recovery link clicked → send to reset screen.
      if (refresh.isRecovery) {
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
      // Hors coque: pas de barre de navigation.
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/study',
        builder: (context, state) => StudyScreen(
          collectionId: state.uri.queryParameters['collectionId'],
          deckId: state.uri.queryParameters['deckId'],
        ),
      ),
      GoRoute(
        path: '/study/errors',
        builder: (context, state) {
          final summary = state.extra as SessionSummary;
          return StudyScreen(
            collectionId: summary.collectionId,
            deckId: summary.deckId,
            errorCardIds: summary.incorrectCardIds,
          );
        },
      ),
      GoRoute(
        path: '/study/:deckId',
        builder: (context, state) =>
            StudyScreen(deckId: state.pathParameters['deckId']),
      ),
      GoRoute(
        path: '/session-summary',
        builder: (context, state) =>
            SessionSummaryScreen(summary: state.extra! as SessionSummary),
      ),
      // Coque à quatre onglets: l'état de chaque onglet est conservé.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            TabShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'collection/:collectionId',
                    builder: (context, state) => CollectionDetailScreen(
                      collectionId: state.pathParameters['collectionId']!,
                    ),
                    routes: [
                      GoRoute(
                        name: 'collection-due-cards',
                        path: 'due-cards',
                        builder: (context, state) => CollectionDueCardsScreen(
                          collectionId: state.pathParameters['collectionId']!,
                          collectionName:
                              state.uri.queryParameters['name'] ?? 'Collection',
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'deck/:deckId/cards',
                    builder: (context, state) => DeckCardsScreen(
                      deckId: state.pathParameters['deckId']!,
                      deckName: state.uri.queryParameters['name'] ?? 'Deck',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (context, state) => const StatisticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/import',
                builder: (context, state) => const ImportScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
              GoRoute(
                path: '/legal/:doc',
                builder: (context, state) => LegalDocumentScreen(
                  document: LegalDocument.fromSlug(
                    state.pathParameters['doc']!,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Hôte des quatre onglets: possède la barre de navigation. Un changement
/// d'onglet fait un fondu léger (`fast`) du corps; la pile des onglets n'est
/// pas reconstruite, donc l'état de chaque onglet est conservé.
class TabShell extends StatefulWidget {
  const TabShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: AppMotion.fast,
    value: 1,
  );
  late final Animation<double> _opacity = _fade.drive(
    CurveTween(curve: AppMotion.standardCurve),
  );

  @override
  void didUpdateWidget(TabShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex ==
        widget.navigationShell.currentIndex) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _fade.value = 1;
    } else {
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;
    final body = FadeTransition(
      opacity: _opacity,
      child: widget.navigationShell,
    );
    return Scaffold(
      body: tablet
          ? Row(
              children: [
                AppNavRail(navigationShell: widget.navigationShell),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: tablet
          ? null
          : AppBottomNav(navigationShell: widget.navigationShell),
    );
  }
}
