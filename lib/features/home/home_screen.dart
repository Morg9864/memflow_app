import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/ui.dart';

final homeStatsProvider = StreamProvider<HomeStats>((ref) {
  return ref.watch(appRepositoryProvider).watchHomeStats();
});

final homeCollectionsProvider =
    StreamProvider.family<List<CollectionListItem>, String>((ref, search) {
  return ref.watch(appRepositoryProvider).watchCollections(search: search);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(homeStatsProvider);
    final collections = ref.watch(homeCollectionsProvider(_search));
    final displayName = ref.watch(displayNameProvider);
    final location = GoRouterState.of(context).uri.path;

    return AppScaffold(
      bottomNavigation: AppBottomNav(location: location),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.headlineMedium,
                  children: [
                    TextSpan(
                      text: 'Mem',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                    ),
                    TextSpan(
                      text: 'Flow',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: () => context.push('/stats'),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              const SizedBox(width: 8),
              const ThemeToggleButton(),
            ],
          ),
          const SizedBox(height: 28),
          stats.when(
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(
                  displayName == null ? 'Bonjour' : 'Bonjour, $displayName',
                ),
                const SizedBox(height: 8),
                Text(
                  '${data.dueCards} cartes t’attendent ce matin.',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => Text(error.toString()),
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher une collection',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                stats.when(
                  data: (data) => GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 720 ? 3 : 1,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.45,
                    children: [
                      StatCard(
                        value: '${data.streakDays}j',
                        label: 'de série',
                        icon: Icons.local_fire_department_rounded,
                      ),
                      StatCard(
                        value: '${(data.successRate * 100).round()}%',
                        label: 'réussite',
                        icon: Icons.trending_up_rounded,
                      ),
                      StatCard(
                        value: '${data.dueCards}',
                        label: 'à revoir',
                        icon: Icons.schedule_rounded,
                      ),
                    ],
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    const SectionLabel('Collections'),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.push('/import'),
                      child: const Text('Importer CSV'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                collections.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const EmptyState(
                        title: 'Aucune collection',
                        message: 'Ajuste la recherche ou importe un nouveau jeu de cartes.',
                      );
                    }

                    final featured = items.first;
                    final others = items.where((item) => item.id != featured.id).toList();
                    final crossAxisCount = MediaQuery.of(context).size.width > 860 ? 2 : 1;

                    return Column(
                      children: [
                        FeaturedCollectionCard(
                          collection: featured,
                          onTap: () => context.push('/collection/${featured.id}'),
                        ),
                        const SizedBox(height: 14),
                        GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.22,
                          children: [
                            for (final item in others)
                              CollectionCard(
                                collection: item,
                                onTap: () => context.push('/collection/${item.id}'),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) => Text(error.toString()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
