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
      child: SyncRefreshIndicator(
        child: ListView(
          children: [
            Row(
              children: [
                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.headlineMedium,
                    children: [
                      TextSpan(
                        text: 'Mem',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      TextSpan(
                        text: 'Flow',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: 'Voir les statistiques',
                  onPressed: () => context.push('/stats'),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                const SizedBox(width: 8),
                const SyncNowButton(),
              ],
            ),
            const SizedBox(height: 28),
            stats.when(
              data: (data) {
                final due = data.dueCards;
                final goalReached = due == 0;
                final subtitle = goalReached
                    ? 'Tout est à jour !'
                    : '$due cartes à revoir';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(
                      displayName == null ? 'Bonjour' : 'Bonjour, $displayName',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => Text(error.toString()),
            ),
            const SizedBox(height: 24),
            stats.when(
              data: (data) {
                final canStudy = data.dueCards > 0;
                return Semantics(
                  button: true,
                  label: canStudy
                      ? 'Commencer une session de ${data.dueCards} cartes'
                      : 'Aucune carte à réviser aujourd’hui',
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('home-study-cta'),
                      onPressed: canStudy ? () => context.push('/study') : null,
                      icon: Icon(
                        canStudy
                            ? Icons.play_arrow_rounded
                            : Icons.check_circle_outline_rounded,
                      ),
                      label: Text(
                        canStudy
                            ? 'Étudier maintenant · ${data.dueCards} cartes'
                            : 'Tout est à jour',
                      ),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox(height: 56),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher une collection',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 24),
            stats.when(
              data: (data) => GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 2,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 120,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemBuilder: (context, index) => index == 0
                    ? StatCard(
                        compact: true,
                        horizontal: true,
                        value: '${data.streakDays}j',
                        label: 'de série',
                        icon: Icons.local_fire_department_rounded,
                      )
                    : StatCard(
                        compact: true,
                        horizontal: true,
                        value: '${data.dueCards}',
                        label: 'à revoir',
                        icon: Icons.schedule_rounded,
                      ),
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
                    message:
                        'Ajuste la recherche ou importe un nouveau jeu de cartes.',
                  );
                }

                final activeItems = items
                    .where((item) => !item.isDisabled)
                    .toList();
                final disabledItems = items
                    .where((item) => item.isDisabled)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (activeItems.isNotEmpty) ...[
                      _CollectionGrid(items: activeItems),
                      if (disabledItems.isNotEmpty) const SizedBox(height: 28),
                    ],
                    if (disabledItems.isNotEmpty) ...[
                      const SectionLabel('Désactivé(s)'),
                      const SizedBox(height: 12),
                      _CollectionGrid(items: disabledItems),
                    ],
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
    );
  }
}

class _CollectionGrid extends StatelessWidget {
  const _CollectionGrid({required this.items});

  final List<CollectionListItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: cardWidth,
                child: CollectionCard(
                  collection: item,
                  onTap: () => context.push('/collection/${item.id}'),
                ),
              ),
          ],
        );
      },
    );
  }
}
