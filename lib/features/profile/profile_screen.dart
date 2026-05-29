import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/ui.dart';
import '../legal/legal_document_screen.dart';

// Provider wired to the sync service so the profile can trigger a re-sync.
final _syncServiceProfileProvider = Provider((ref) => ref.watch(syncServiceProvider));

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _supportEmail = 'morgan.phemba@gmail.com';

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
      ..writeln('Je souhaite la suppression de mon compte MemFlow et des '
          'données associées.')
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
            content: Text('Impossible d\'ouvrir l\'app mail. '
                'Écris-nous à $_supportEmail.'),
          ),
        );
    }
  }

  String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
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

  Future<void> _forceSync() async {
    final syncService = ref.read(_syncServiceProfileProvider);
    if (!syncService.isEnabled) return;
    setState(() => _busy = true);
    try {
      await syncService.resetSyncCursor();
      await syncService.runSync();
      await ref.read(appRepositoryProvider).refreshAllDerivedData();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Synchronisation terminée.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Erreur sync : $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final authService = ref.read(authServiceProvider);
    if (authService == null) {
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    final themePreference = ref.watch(themeControllerProvider);
    final user = ref.watch(currentUserProvider);
    final displayName = ref.watch(displayNameProvider);
    return AppScaffold(
      bottomNavigation: AppBottomNav(location: GoRouterState.of(context).uri.path),
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
                    displayName ?? 'Invité',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (user?.email != null) ...[
                    const SizedBox(height: 4),
                    Text(user!.email!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 6),
                  Text('Objectif quotidien : 12 cartes', style: Theme.of(context).textTheme.bodyLarge),
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
                  Text(
                    'Version app',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('1.1.24', style: Theme.of(context).textTheme.bodyMedium),
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
                  onTap: () => context.push('/legal/${LegalDocument.privacy.slug}'),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text("Conditions d'utilisation"),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/legal/${LegalDocument.terms.slug}'),
                ),
                ListTile(
                  leading: const Icon(Icons.gavel_rounded),
                  title: const Text('Mentions légales'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/legal/${LegalDocument.notices.slug}'),
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
                    if (ref.read(_syncServiceProfileProvider).isEnabled) ...[
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _forceSync,
                        icon: const Icon(Icons.sync_rounded),
                        label: const Text('Forcer la synchronisation'),
                      ),
                      const SizedBox(height: 12),
                    ],
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
                      label: const Text('Demander la suppression de mon compte'),
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
