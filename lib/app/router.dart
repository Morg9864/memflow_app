import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/collections/collection_detail_screen.dart';
import '../features/home/home_screen.dart';
import '../features/import/import_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/study/session_summary_screen.dart';
import '../features/study/study_screen.dart';
import '../domain/models/models.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
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
        path: '/session-summary',
        builder: (context, state) => SessionSummaryScreen(
          summary: state.extra! as SessionSummary,
        ),
      ),
    ],
  );
});
