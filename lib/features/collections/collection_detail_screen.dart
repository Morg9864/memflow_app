import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/ui.dart';

final collectionProvider =
    StreamProvider.family<CollectionListItem?, String>((ref, collectionId) {
  return ref.watch(appRepositoryProvider).watchCollection(collectionId);
});

final collectionDecksProvider =
    StreamProvider.family<List<DeckListItem>, String>((ref, collectionId) {
  return ref.watch(appRepositoryProvider).watchDecksForCollection(collectionId);
});

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
  });

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(collectionProvider(collectionId));
    final decks = ref.watch(collectionDecksProvider(collectionId));
    final deckCount = decks.asData?.value.length;

    return AppScaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/study?collectionId=$collectionId'),
        child: const Icon(Icons.play_arrow_rounded),
      ),
      child: collection.when(
        data: (item) {
          if (item == null) {
            return const EmptyState(
              title: 'Collection introuvable',
              message: 'Cette collection n’existe pas ou n’est plus disponible.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                  const ThemeToggleButton(),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Color(item.color).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Text(item.icon, style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(height: 18),
              Text(item.name, style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(item.description, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      value: '${item.totalCards}',
                      label: 'cartes',
                      icon: Icons.style_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      value: '${(item.masteredPercentage * 100).round()}%',
                      label: 'maîtrise',
                      icon: Icons.stars_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      value: '${item.dueCards}',
                      label: 'dues',
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const SectionLabel('Decks'),
                  const Spacer(),
                  Text(deckCount == null ? '' : '$deckCount packs'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: decks.when(
                  data: (deckItems) => ListView(
                    children: [
                      for (final deck in deckItems) ...[
                        DeckCard(
                          deck: deck,
                          onTap: () => context.push('/study?deckId=${deck.id}'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton.tonalIcon(
                        onPressed: () => context.push('/import'),
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Importer un CSV'),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Text(error.toString()),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(error.toString()),
      ),
    );
  }
}
