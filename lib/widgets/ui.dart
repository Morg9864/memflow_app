import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/models.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.bottomNavigation,
    this.floatingActionButton,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
  });

  final Widget child;
  final Widget? bottomNavigation;
  final Widget? floatingActionButton;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigation,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.location});

  final String location;

  int get _currentIndex {
    if (location.startsWith('/stats')) return 1;
    if (location.startsWith('/import')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.go('/');
          case 1:
            context.go('/stats');
          case 2:
            context.go('/import');
          case 3:
            context.go('/profile');
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Accueil'),
        NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'Stats'),
        NavigationDestination(icon: Icon(Icons.upload_file_rounded), label: 'Importer'),
        NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profil'),
      ],
    );
  }
}

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);
    final isDark = theme == ThemePreference.dark ||
        (theme == ThemePreference.system && Theme.of(context).brightness == Brightness.dark);
    return IconButton.filledTonal(
      tooltip: 'Changer de thème',
      onPressed: () {
        ref.read(themeControllerProvider.notifier).setPreference(
              isDark ? ThemePreference.light : ThemePreference.dark,
            );
      },
      icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium,
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(icon: icon),
            const SizedBox(height: 16),
            Text(value, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background ?? theme.colorScheme.primary.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: foreground ?? theme.colorScheme.primary,
        size: 20,
      ),
    );
  }
}

class ProgressPill extends StatelessWidget {
  const ProgressPill({
    super.key,
    required this.value,
    this.height = 7,
  });

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: height,
        value: value.clamp(0, 1),
        backgroundColor: theme.brightness == Brightness.dark
            ? const Color(0xFF3A2A21)
            : const Color(0xFFF1E7DC),
        valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
      ),
    );
  }
}

class FeaturedCollectionCard extends StatelessWidget {
  const FeaturedCollectionCard({
    super.key,
    required this.collection,
    required this.onTap,
  });

  final CollectionListItem collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.radiusLg,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: AppTheme.radiusLg,
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              Color(collection.color),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Collection phare'.toUpperCase(), style: theme.textTheme.labelMedium?.copyWith(color: Colors.white70)),
              const SizedBox(height: 10),
              Text(collection.name,
                  style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                collection.description,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _metricChip(context, '${collection.totalCards}', 'cartes'),
                  const SizedBox(width: 12),
                  _metricChip(context, '${(collection.masteredPercentage * 100).round()}%', 'maîtrise'),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white.withValues(alpha: 0.95)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricChip(BuildContext context, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$value $label',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
    );
  }
}

class CollectionCard extends StatelessWidget {
  const CollectionCard({
    super.key,
    required this.collection,
    required this.onTap,
  });

  final CollectionListItem collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: AppTheme.radiusMd,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Color(collection.color).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(collection.icon, style: const TextStyle(fontSize: 20)),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_outward_rounded, color: theme.colorScheme.primary),
                ],
              ),
              const Spacer(),
              Text(collection.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('${collection.totalCards} cartes', style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              ProgressPill(value: collection.masteredPercentage),
            ],
          ),
        ),
      ),
    );
  }
}

class DeckCard extends StatelessWidget {
  const DeckCard({
    super.key,
    required this.deck,
    required this.onTap,
    this.onDelete,
    this.onViewCards,
  });

  final DeckListItem deck;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onViewCards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasOptions = onDelete != null || onViewCards != null;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.radiusMd,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(deck.icon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deck.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      '${deck.totalCards} cartes • ${deck.difficulty.label}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    ProgressPill(value: deck.progress),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (hasOptions)
                PopupMenuButton<_DeckAction>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (action) {
                    switch (action) {
                      case _DeckAction.viewCards:
                        onViewCards?.call();
                      case _DeckAction.delete:
                        onDelete?.call();
                    }
                  },
                  itemBuilder: (_) => [
                    if (onViewCards != null)
                      const PopupMenuItem(
                        value: _DeckAction.viewCards,
                        child: Row(
                          children: [
                            Icon(Icons.list_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Voir les cartes'),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: _DeckAction.delete,
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                color: theme.colorScheme.error, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              'Supprimer le deck',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(deck.badgeLabel, style: theme.textTheme.bodySmall),
                    ),
                    const SizedBox(height: 14),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DeckAction { viewCards, delete }

class LevelBadge extends StatelessWidget {
  const LevelBadge({
    super.key,
    required this.level,
  });

  final int level;

  @override
  Widget build(BuildContext context) {
    final meta = switch (level) {
      1 => ('Basique', Icons.visibility_rounded),
      2 => ('Intermédiaire', Icons.auto_awesome_mosaic_rounded),
      3 => ('Actif', Icons.bolt_rounded),
      _ => ('Avancé', Icons.psychology_alt_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.$2, size: 16),
          const SizedBox(width: 8),
          Text('${meta.$1}, Niv. $level'),
        ],
      ),
    );
  }
}

class StudyProgressHeader extends StatelessWidget {
  const StudyProgressHeader({
    super.key,
    required this.title,
    required this.currentIndex,
    required this.total,
    required this.level,
    required this.progressDots,
    this.onClose,
  });

  final String title;
  final int currentIndex;
  final int total;
  final int level;
  final int progressDots;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 12),
        ProgressPill(value: total == 0 ? 0 : (currentIndex + 1) / total),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('${currentIndex + 1}/$total'),
            const SizedBox(width: 12),
            LevelBadge(level: level),
            const Spacer(),
            Row(
              children: List.generate(
                progressDots,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: index <= currentIndex
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
}

class ReviewButton extends StatelessWidget {
  const ReviewButton({
    super.key,
    required this.result,
    required this.onPressed,
    this.isSuggested = false,
    this.enabled = true,
  });

  final ReviewResult result;
  final VoidCallback? onPressed;
  final bool isSuggested;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = result.tone(scheme);
    final background = result.background(scheme);
    final borderColor = isSuggested ? tone : Colors.transparent;

    return FilledButton(
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(88),
        padding: const EdgeInsets.all(16),
        backgroundColor: background,
        foregroundColor: tone,
        disabledBackgroundColor: background.withValues(alpha: 0.55),
        disabledForegroundColor: tone.withValues(alpha: 0.55),
        elevation: 0,
        tapTargetSize: MaterialTapTargetSize.padded,
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: borderColor,
            width: isSuggested ? 1.5 : 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: tone),
          ),
          const SizedBox(height: 6),
          Text(
            result.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tone),
          ),
        ],
      ),
    );
  }
}

class HeatmapGrid extends StatelessWidget {
  const HeatmapGrid({super.key, required this.rows});

  final List<List<HeatmapCell>> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: const [
            SizedBox(width: 28),
            Expanded(child: Text('L')),
            Expanded(child: Text('M')),
            Expanded(child: Text('M')),
            Expanded(child: Text('J')),
            Expanded(child: Text('V')),
            Expanded(child: Text('S')),
            Expanded(child: Text('D')),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(rows.length, (weekIndex) {
          final row = rows[weekIndex];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(width: 28, child: Text('S${weekIndex + 1}')),
                ...row.map(
                  (cell) => Expanded(
                    child: Container(
                      height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: cell.isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF30231A)
                                : const Color(0xFFF3EADF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories_rounded, size: 40),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
