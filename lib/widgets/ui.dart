import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../data/sync/sync_service.dart';
import '../theme/app_theme.dart';

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
            constraints: const BoxConstraints(
              maxWidth: AppTheme.contentMaxWidth,
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Demande une synchronisation puis laisse les streams SQLite rafraîchir les
/// vues. La base locale reste la source de vérité pendant l'opération.
class SyncRefreshIndicator extends ConsumerWidget {
  const SyncRefreshIndicator({super.key, required this.child, this.onRefresh});

  final Widget child;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        try {
          await ref.read(syncServiceProvider).syncNow();
          await onRefresh?.call();
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Synchronisation impossible: $error')),
            );
          }
        }
      },
      child: child,
    );
  }
}

/// Action explicite pour les formats tablette/desktop. Sur mobile, le geste
/// pull-to-refresh est l'affordance principale.
class SyncNowButton extends ConsumerWidget {
  const SyncNowButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (MediaQuery.sizeOf(context).width < 700) {
      return const SizedBox.shrink();
    }
    final status = ref.watch(syncStatusProvider).value;
    final syncing = status?.state == SyncState.syncing;
    return IconButton.filledTonal(
      key: const ValueKey('sync-now-icon-button'),
      tooltip: syncing ? 'Synchronisation en cours' : 'Synchroniser',
      onPressed: syncing ? null : () => ref.read(syncServiceProvider).syncNow(),
      icon: syncing
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync_rounded),
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
        NavigationDestination(
          icon: Icon(Icons.insights_rounded),
          label: 'Stats',
        ),
        NavigationDestination(
          icon: Icon(Icons.upload_file_rounded),
          label: 'Importer',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_rounded),
          label: 'Profil',
        ),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.compact = false,
    this.horizontal = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool compact;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconWidget = compact
        ? IconTile(icon: icon, size: 30)
        : IconTile(icon: icon);
    final textWidget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontFeatures: AppTheme.tabularFigures,
          ),
        ),
        SizedBox(height: compact ? 2 : AppSpacing.xs),
        Text(
          label,
          style: compact
              ? theme.textTheme.labelMedium
              : theme.textTheme.bodySmall,
        ),
      ],
    );
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 18),
        child: horizontal
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  iconWidget,
                  SizedBox(width: compact ? 10 : 16),
                  Expanded(child: textWidget),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  iconWidget,
                  SizedBox(height: compact ? 6 : 16),
                  textWidget,
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
    this.size = 40,
  });

  final IconData icon;
  final Color? background;
  final Color? foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? theme.colorScheme.primary.withValues(alpha: 0.11),
        borderRadius: AppTheme.radiusSm,
      ),
      child: Icon(
        icon,
        color: foreground ?? theme.colorScheme.primary,
        size: size * 0.5,
      ),
    );
  }
}

class ProgressPill extends StatelessWidget {
  const ProgressPill({
    super.key,
    required this.value,
    this.height = 7,
    this.semanticsLabel,
  });

  final double value;
  final double height;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = value.clamp(0, 1).toDouble();
    // begin == end: le premier build ne part pas de zéro; les changements
    // suivants s'animent depuis la valeur affichée.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: target, end: target),
      duration: AppMotion.of(context, AppMotion.standard),
      curve: AppMotion.standardCurve,
      builder: (context, animated, _) => ClipRRect(
        borderRadius: AppTheme.radiusPill,
        child: LinearProgressIndicator(
          minHeight: height,
          value: animated,
          semanticsLabel: semanticsLabel,
          semanticsValue: '${(target * 100).round()} %',
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
        ),
      ),
    );
  }
}

/// Pastille « Désactivé(e) » partagée par les cartes de collection et de deck.
class DisabledBadge extends StatelessWidget {
  const DisabledBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.outline.withValues(alpha: 0.18),
        borderRadius: AppTheme.radiusPill,
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.auto_stories_rounded,
  });

  final String title;
  final String message;
  final Widget? action;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(icon: icon, size: 56),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// État d'erreur sans objet d'erreur: aucun texte d'exception n'atteint
/// l'utilisateur.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Une erreur est survenue',
    this.message = 'Réessaie dans un instant.',
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: title,
      message: message,
      action: onRetry == null
          ? null
          : FilledButton.tonal(
              style: AppTheme.secondaryAction,
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
    );
  }
}

/// Retour tactile: compresse légèrement l'enfant pendant l'appui. `Listener`
/// n'entre pas dans l'arène des gestes et n'ajoute pas de sémantique.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final scale =
        _down && widget.enabled && !MediaQuery.disableAnimationsOf(context)
        ? 0.98
        : 1.0;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: scale,
        duration: AppMotion.fast,
        child: widget.child,
      ),
    );
  }
}

/// Indicateur de chargement 18 px pour l'intérieur d'un bouton. Un bouton en
/// chargement est désactivé : le neutre atténué reste lisible, contrairement à
/// la couleur désactivée dont il hériterait.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Bloc statique de chargement (sans shimmer), ignoré par les lecteurs d'écran.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius});

  final double? width;
  final double height;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: radius ?? AppTheme.radiusSm,
        ),
      ),
    );
  }
}
