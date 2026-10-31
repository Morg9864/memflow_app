import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

/// Carte de réglages : un [SectionLabel] optionnel au-dessus, puis des lignes
/// uniformes séparées par de fins filets. Partagée par le profil et les
/// paramètres (`ui.dart` est gelé pour l'instant).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.label, required this.children});

  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: SectionLabel(label!),
          ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) divider,
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Ligne de réglage : icône 24 px atténuée, titre, sous-titre et élément de
/// fin optionnels. Le texte passe à la ligne plutôt que d'être tronqué.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Remplace l'icône (par exemple un indicateur de chargement).
  final Widget? leading;
  final VoidCallback? onTap;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      minTileHeight: 56,
      leading: leading ?? Icon(icon, size: 24),
      iconColor: destructive ? scheme.error : scheme.onSurfaceVariant,
      textColor: destructive ? scheme.error : scheme.onSurface,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing,
      enabled: enabled,
      onTap: onTap,
    );
  }
}
