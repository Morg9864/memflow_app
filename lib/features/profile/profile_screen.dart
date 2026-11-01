import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../app/app_version.dart';
import '../../app/daily_goal_controller.dart';
import '../../app/providers.dart';
import '../../data/sync/sync_service.dart';
import '../../widgets/ui.dart';
import '../legal/legal_document_screen.dart';
import 'settings_row.dart';

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
          FilledButton.tonal(
            style: AppTheme.compactAction,
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
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _DailyGoalDialog(initial: current),
    );
    if (result != null) {
      await ref.read(dailyGoalProvider.notifier).setGoal(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final displayName = ref.watch(displayNameProvider);
    final dailyGoal = ref.watch(dailyGoalProvider);
    const gap = SizedBox(height: AppSpacing.xl);
    return AppScaffold(
      maxContentWidth: AppTheme.formMaxWidth,
      child: ListView(
        children: [
          Semantics(
            header: true,
            child: Text('Profil', style: theme.textTheme.displaySmall),
          ),
          gap,
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName ?? 'Utilisateur',
                    style: theme.textTheme.titleLarge,
                  ),
                  if (user?.email != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(user!.email!, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
          if (user != null) ...[
            gap,
            SettingsGroup(
              label: 'Compte',
              children: [
                SettingsRow(
                  icon: Icons.settings_outlined,
                  title: 'Paramètres du compte',
                  subtitle: 'Nom, email, mot de passe',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),
          ],
          gap,
          SettingsGroup(
            label: 'Révision',
            children: [
              SettingsRow(
                icon: Icons.flag_outlined,
                title: 'Objectif quotidien',
                subtitle: '$dailyGoal cartes par jour',
                trailing: const Icon(
                  Icons.edit_outlined,
                  semanticLabel: 'Modifier',
                ),
                onTap: _editDailyGoal,
              ),
            ],
          ),
          gap,
          SettingsGroup(
            label: 'Données et synchronisation',
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: _SyncStatusLine(),
              ),
              SettingsRow(
                icon: Icons.download_rounded,
                leading: _busy ? const ButtonSpinner() : null,
                title: 'Exporter les cartes en CSV',
                enabled: !_busy,
                onTap: _exportCsv,
              ),
              const SettingsRow(
                icon: Icons.info_outline_rounded,
                title: 'Version app',
                subtitle: appVersion,
              ),
            ],
          ),
          gap,
          SettingsGroup(
            label: 'Légal',
            children: [
              SettingsRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Politique de confidentialité',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    context.push('/legal/${LegalDocument.privacy.slug}'),
              ),
              SettingsRow(
                icon: Icons.description_outlined,
                title: "Conditions d'utilisation",
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/legal/${LegalDocument.terms.slug}'),
              ),
              SettingsRow(
                icon: Icons.gavel_rounded,
                title: 'Mentions légales',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    context.push('/legal/${LegalDocument.notices.slug}'),
              ),
              SettingsRow(
                icon: Icons.article_outlined,
                title: 'Licences open-source',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showMemFlowLicensePage(context),
              ),
            ],
          ),
          if (user != null) ...[
            gap,
            SettingsGroup(
              label: 'Session',
              children: [
                SettingsRow(
                  icon: Icons.logout_rounded,
                  title: 'Se déconnecter',
                  enabled: !_busy,
                  onTap: _signOut,
                ),
                SettingsRow(
                  icon: Icons.delete_outline_rounded,
                  title: 'Demander la suppression de mon compte',
                  destructive: true,
                  enabled: !_busy,
                  onTap: _requestAccountDeletion,
                ),
              ],
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
    final onSurface = theme.colorScheme.onSurface;
    final status = ref.watch(syncStatusProvider).value;
    final pending = status?.pendingCount ?? 0;
    final lastSynced = status?.lastSyncedAt;

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
      SyncState.error => (
        Icons.cloud_off_outlined,
        'Synchronisation impossible',
        status?.errorMessage ??
            'La synchronisation a échoué. Réessaie plus tard.',
        theme.colorScheme.error,
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
          borderRadius: AppTheme.radiusSm,
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (lastSynced != null) ...[
              const SizedBox(height: 8),
              Text(
                'Dernière synchronisation : ${_formatSyncDate(lastSynced)}',
                style: theme.textTheme.bodySmall?.copyWith(color: onSurface),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('sync-now-button'),
                style: TextButton.styleFrom(
                  foregroundColor: onSurface,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: status?.state == SyncState.syncing
                    ? null
                    : () => ref.read(syncServiceProvider).syncNow(),
                icon: Icon(Icons.sync_rounded, size: 18, color: color),
                label: const Text('Synchroniser maintenant'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSyncDate(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} à '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _DailyGoalDialog extends StatefulWidget {
  const _DailyGoalDialog({required this.initial});

  final int initial;

  @override
  State<_DailyGoalDialog> createState() => _DailyGoalDialogState();
}

class _DailyGoalDialogState extends State<_DailyGoalDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.initial}',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Objectif quotidien'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
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
        FilledButton.tonal(
          style: AppTheme.compactAction,
          onPressed: _submit,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 1) {
      setState(() => _error = 'Entrer un nombre entre 1 et 999.');
      return;
    }
    Navigator.of(context).pop(value);
  }
}
