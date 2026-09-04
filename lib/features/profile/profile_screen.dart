import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_version.dart';
import '../../app/daily_goal_controller.dart';
import '../../app/providers.dart';
import '../../data/sync/sync_service.dart';
import '../../domain/models/models.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/ui.dart';
import '../legal/legal_document_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _supportEmail = 'contact@morganphemba.be';

  bool _busy = false;

  /// Opens the user's mail client pre-filled with a deletion request to the
  /// support address. Account deletion is handled manually for now.
  Future<void> _requestAccountDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demander la suppression du compte'),
        content: const Text(
          'Un email pré-rempli va s\'ouvrir vers notre support. '
          'Ta demande sera traitée manuellement sous quelques jours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    final user = ref.read(currentUserProvider);
    final body = StringBuffer()
      ..writeln('Bonjour,')
      ..writeln()
      ..writeln(
        'Je souhaite la suppression de mon compte MemFlow et des '
        'données associées.',
      )
      ..writeln()
      ..writeln('Email du compte : ${user?.email ?? 'non renseigné'}')
      ..writeln('Identifiant : ${user?.id ?? 'non renseigné'}');

    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: _encodeQuery({
        'subject': 'Demande de suppression de compte MemFlow',
        'body': body.toString(),
      }),
    );

    var launched = false;
    try {
      launched = await launchUrl(uri);
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible d\'ouvrir l\'app mail. '
              'Écris-nous à $_supportEmail.',
            ),
          ),
        );
    }
  }

  String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  Future<void> _exportCsv() async {
    setState(() => _busy = true);
    try {
      final content = await ref.read(appRepositoryProvider).exportAllCardsCsv();
      await FilePicker.saveFile(
        dialogTitle: 'Exporter les cartes',
        fileName: 'memflow_cards.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: utf8.encode(content),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _signOut() async {
    final authService = ref.read(authServiceProvider);
    setState(() => _busy = true);
    try {
      await authService.signOut();
      // The router's auth redirect sends us back to /auth.
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _editDailyGoal() async {
    final current = ref.read(dailyGoalProvider);
    final controller = TextEditingController(text: '$current');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _DailyGoalDialog(controller: controller),
    );
    if (result != null) {
      await ref.read(dailyGoalProvider.notifier).setGoal(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themePreference = ref.watch(themeControllerProvider);
    final user = ref.watch(currentUserProvider);
    final displayName = ref.watch(displayNameProvider);
    final dailyGoal = ref.watch(dailyGoalProvider);
    return AppScaffold(
      bottomNavigation: AppBottomNav(
        location: GoRouterState.of(context).uri.path,
      ),
      child: ListView(
        children: [
          Row(
            children: [
              Text('Profil', style: Theme.of(context).textTheme.displaySmall),
              const Spacer(),
              const ThemeToggleButton(),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName ?? 'Utilisateur',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (user?.email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      user!.email!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _editDailyGoal,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Objectif quotidien : $dailyGoal cartes',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Thème'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    children: ThemePreference.values
                        .map(
                          (preference) => ChoiceChip(
                            label: Text(preference.label),
                            selected: themePreference == preference,
                            onSelected: (_) => ref
                                .read(themeControllerProvider.notifier)
                                .setPreference(preference),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _exportCsv,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Exporter les cartes en CSV'),
                  ),
                  const SizedBox(height: 16),
                  const _SyncStatusLine(),
                  const SizedBox(height: 16),
                  Text(
                    'Version app',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appVersion,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SectionLabel('Légal'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Politique de confidentialité'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      context.push('/legal/${LegalDocument.privacy.slug}'),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text("Conditions d'utilisation"),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      context.push('/legal/${LegalDocument.terms.slug}'),
                ),
                ListTile(
                  leading: const Icon(Icons.gavel_rounded),
                  title: const Text('Mentions légales'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      context.push('/legal/${LegalDocument.notices.slug}'),
                ),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('Licences open-source'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showMemFlowLicensePage(context),
                ),
              ],
            ),
          ),
          if (user != null) ...[
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Paramètres du compte'),
                subtitle: const Text('Nom, email, mot de passe'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/settings'),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Se déconnecter'),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _busy ? null : _requestAccountDeletion,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text(
                        'Demander la suppression de mon compte',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// L'application écrit d'abord en local : elle doit dire ce qui n'est pas
/// encore parti, sinon l'utilisateur ne peut pas savoir s'il peut changer
/// d'appareil sans rien perdre.
class _SyncStatusLine extends ConsumerWidget {
  const _SyncStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = ref.watch(syncStatusProvider).value;
    final pending = status?.pendingCount ?? 0;

    final (icon, title, detail, color) = switch (status?.state) {
      SyncState.offline => (
        Icons.cloud_off_outlined,
        'Hors ligne',
        pending == 0
            ? 'Aucune modification en attente. Les données locales restent disponibles.'
            : '$pending modification${pending > 1 ? 's' : ''} en attente d\'envoi. Elles seront envoyées dès la reconnexion.',
        theme.colorScheme.error,
      ),
      SyncState.syncing => (
        Icons.cloud_sync_outlined,
        'Synchronisation en cours…',
        pending == 0
            ? 'Les dernières données sont en cours de vérification.'
            : '$pending modification${pending > 1 ? 's' : ''} en attente d\'envoi.',
        theme.colorScheme.primary,
      ),
      null || SyncState.idle => (
        Icons.cloud_done_outlined,
        'Synchronisé',
        pending == 0
            ? 'Toutes les modifications sont enregistrées.'
            : '$pending modification${pending > 1 ? 's' : ''} en attente d\'envoi.',
        theme.colorScheme.primary,
      ),
    };

    return Semantics(
      container: true,
      label: '$title. $detail',
      child: Container(
        key: const ValueKey('sync-status-panel'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(detail, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyGoalDialog extends StatefulWidget {
  const _DailyGoalDialog({required this.controller});

  final TextEditingController controller;

  @override
  State<_DailyGoalDialog> createState() => _DailyGoalDialogState();
}

class _DailyGoalDialogState extends State<_DailyGoalDialog> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Objectif quotidien'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nombre de cartes par jour',
              suffixText: 'cartes',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }

  void _submit() {
    final value = int.tryParse(widget.controller.text.trim());
    if (value == null || value < 1) {
      setState(() => _error = 'Entrer un nombre entre 1 et 999.');
      return;
    }
    Navigator.of(context).pop(value);
  }
}
