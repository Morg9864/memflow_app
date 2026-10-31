import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/ui.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, @visibleForTesting this.pickFiles});

  /// Test seam: replaces the static `FilePicker.pickFiles` call.
  final Future<FilePickerResult?> Function()? pickFiles;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  CsvImportPreview? _preview;
  bool _isBusy = false;
  bool _isImporting = false;
  bool _readFailed = false;
  bool _importFailed = false;
  String? _fileName;
  String? _csvPrompt;

  @override
  void initState() {
    super.initState();
    _loadCsvPrompt();
  }

  Future<void> _loadCsvPrompt() async {
    final prompt = await rootBundle.loadString(
      'md/prompt_csv_memflow_neutre.md',
    );
    if (!mounted) {
      return;
    }
    setState(() => _csvPrompt = prompt);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result;
    try {
      result =
          await (widget.pickFiles?.call() ??
              FilePicker.pickFiles(
                withData: true,
                type: FileType.custom,
                allowedExtensions: const ['csv', 'txt'],
              ));
    } catch (_) {
      _snack('Impossible d’ouvrir le sélecteur de fichiers.');
      return;
    }
    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }
    final file = result.files.single;
    final bytes = file.bytes;
    CsvImportPreview? preview;
    if (bytes != null) {
      try {
        preview = ref.read(csvImportServiceProvider).parse(bytes);
      } catch (_) {
        preview = null;
      }
    }
    setState(() {
      _preview = preview;
      _fileName = file.name;
      _readFailed = preview == null;
      _importFailed = false;
    });
  }

  Future<void> _downloadTemplate() async {
    try {
      final template = ref.read(csvExportServiceProvider).buildTemplate();
      await FilePicker.saveFile(
        dialogTitle: 'Télécharger le template CSV',
        fileName: 'memflow_template.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: utf8.encode(template),
      );
    } catch (_) {
      _snack('Impossible d’enregistrer le template.');
    }
  }

  Future<void> _downloadBackup() async {
    setState(() => _isBusy = true);
    try {
      final csv = await ref.read(appRepositoryProvider).exportAllCardsCsv();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      await FilePicker.saveFile(
        dialogTitle: 'Sauvegarder mes cartes',
        fileName: 'memflow_backup_$stamp.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: utf8.encode(csv),
      );
    } catch (_) {
      _snack('Impossible d’enregistrer la sauvegarde.');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _downloadPrompt() async {
    final prompt = _csvPrompt;
    if (prompt == null) {
      return;
    }
    try {
      await FilePicker.saveFile(
        dialogTitle: 'Télécharger le prompt CSV Memflow',
        fileName: 'prompt_csv_memflow_neutre.md',
        type: FileType.custom,
        allowedExtensions: const ['md'],
        bytes: utf8.encode(prompt),
      );
    } catch (_) {
      _snack('Impossible d’enregistrer le prompt.');
    }
  }

  Future<void> _copyPrompt() async {
    final prompt = _csvPrompt;
    if (prompt == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prompt copié dans le presse-papiers.')),
    );
  }

  Future<void> _confirmImport() async {
    final preview = _preview;
    if (preview == null || preview.cards.isEmpty || _isImporting) {
      return;
    }
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la restauration'),
        content: Text(
          '${preview.cards.length} cartes seront ajoutées à vos données locales. '
          'Les cartes déjà présentes ne seront pas supprimées. '
          'Pour éviter les doublons, utilisez une sauvegarde complète sur une base vide.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.tonal(
            style: AppTheme.compactAction,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (shouldImport != true || !mounted) {
      return;
    }
    setState(() {
      _isImporting = true;
      _importFailed = false;
    });
    try {
      await ref.read(appRepositoryProvider).importCards(preview);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go('/');
      messenger.showSnackBar(
        SnackBar(content: Text('${preview.cards.length} cartes importées.')),
      );
    } catch (_) {
      if (mounted) setState(() => _importFailed = true);
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _preview;
    final Widget state;
    if (_readFailed) {
      state = const _MessageCard(
        key: ValueKey('unreadable'),
        title: 'Impossible de lire ce fichier.',
        message:
            'Vérifie que c’est bien un fichier CSV ou TXT, puis choisis-en un autre.',
      );
    } else if (preview == null) {
      state = Padding(
        key: const ValueKey('idle'),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          'Aucun fichier chargé. Choisis un fichier pour prévisualiser les cartes détectées et les erreurs.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else {
      state = _PreviewCard(
        key: ValueKey(preview),
        preview: preview,
        fileName: _fileName,
        isImporting: _isImporting,
        importFailed: _importFailed,
        onConfirm: _confirmImport,
      );
    }
    return AppScaffold(
      child: ListView(
        children: [
          Text('Import CSV', style: theme.textTheme.displaySmall),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconTile(icon: Icons.upload_file_rounded),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Importer des cartes',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Fichiers CSV ou TXT, séparés par ; , ou tabulation, avec ou sans ligne d’en-tête.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: Pressable(
                      enabled: !_isImporting,
                      // Une fois un fichier prêt, « Confirmer » devient l'unique
                      // action principale de l'écran.
                      child: _preview?.cards.isNotEmpty == true
                          ? FilledButton.tonalIcon(
                              style: AppTheme.secondaryAction,
                              onPressed: _isImporting ? null : _pickFile,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Importer un fichier CSV'),
                            )
                          : FilledButton.icon(
                              onPressed: _isImporting ? null : _pickFile,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Importer un fichier CSV'),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.standard),
            switchInCurve: AppMotion.standardCurve,
            child: state,
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              title: Text(
                'Options avancées',
                style: theme.textTheme.titleLarge,
              ),
              children: [
                FilledButton.tonalIcon(
                  style: AppTheme.secondaryAction,
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Télécharger le template CSV'),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonalIcon(
                  style: AppTheme.secondaryAction,
                  onPressed: _isBusy ? null : _downloadBackup,
                  icon: _isBusy
                      ? const ButtonSpinner()
                      : const Icon(Icons.save_alt_rounded),
                  label: const Text('Sauvegarder toutes mes cartes'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    'Format recommandé : collection;deck;question;correct_answer;wrong_answer_1;wrong_answer_2;wrong_answer_3;hint;explanation;level;tags;source;cloze_text;accepted_answers;cloze_answers;cloze_word_bank',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Prompt CSV Memflow',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Lis, copie ou télécharge le prompt complet.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonalIcon(
                  style: AppTheme.secondaryAction,
                  onPressed: _csvPrompt == null ? null : _copyPrompt,
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('Copier le prompt'),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonalIcon(
                  style: AppTheme.secondaryAction,
                  onPressed: _csvPrompt == null ? null : _downloadPrompt,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Télécharger le .md'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 360),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: AppTheme.radiusSm,
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: _csvPrompt == null
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          child: SelectableText(
                            _csvPrompt!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Error-tone message: icon plus text, never colour alone.
class _MessageCard extends StatelessWidget {
  const _MessageCard({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.resultBadSoft,
        borderRadius: AppTheme.radiusMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.resultBadText,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.resultBadText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? theme.colorScheme.onSurface),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    super.key,
    required this.preview,
    required this.fileName,
    required this.isImporting,
    required this.importFailed,
    required this.onConfirm,
  });

  static const _maxIssues = 20;

  final CsvImportPreview preview;
  final String? fileName;
  final bool isImporting;
  final bool importFailed;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issues = preview.issues;
    final hasIssues = issues.isNotEmpty;
    final noCards = preview.cards.isEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prévisualisation', style: theme.textTheme.titleLarge),
            if (fileName != null && fileName!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(fileName!, style: theme.textTheme.bodySmall, maxLines: 2),
            ],
            const SizedBox(height: AppSpacing.md),
            _SummaryRow(
              icon: Icons.check_circle_outline_rounded,
              text: preview.cards.length > 1
                  ? '${preview.cards.length} cartes détectées'
                  : '${preview.cards.length} carte détectée',
            ),
            _SummaryRow(
              icon: hasIssues
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              color: hasIssues ? AppColors.error : null,
              text: issues.length > 1
                  ? '${issues.length} lignes invalides'
                  : '${issues.length} ligne invalide',
            ),
            Text(
              'Séparateur : ${preview.delimiter == '\t' ? 'tabulation' : preview.delimiter}'
              ' · Header : ${preview.withHeader ? 'oui' : 'non'}',
              style: theme.textTheme.bodySmall,
            ),
            if (noCards) ...[
              const SizedBox(height: AppSpacing.lg),
              const _MessageCard(
                title: 'Aucune carte exploitable',
                message:
                    'Aucune carte n’a pu être lue dans ce fichier. Vérifie le séparateur et que chaque ligne contient au moins une question et sa bonne réponse.',
              ),
            ],
            if (hasIssues) ...[
              const SizedBox(height: AppSpacing.lg),
              const SectionLabel('Erreurs'),
              const SizedBox(height: AppSpacing.sm),
              for (final issue in issues.take(_maxIssues))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'Ligne ${issue.rowNumber} : ${issue.message}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              if (issues.length > _maxIssues)
                Text(
                  issues.length - _maxIssues > 1
                      ? 'et ${issues.length - _maxIssues} autres lignes'
                      : 'et 1 autre ligne',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
            if (!noCards) ...[
              const SizedBox(height: AppSpacing.lg),
              const SectionLabel('Aperçu'),
              const SizedBox(height: AppSpacing.sm),
              for (final card in preview.cards.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: AppTheme.radiusSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${card.collection} • ${card.deck}',
                          style: theme.textTheme.labelMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(card.question, style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                ),
              if (importFailed) ...[
                const _MessageCard(
                  title: 'L’import a échoué.',
                  message: 'Tes données n’ont pas été modifiées.',
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              SizedBox(
                width: double.infinity,
                child: Pressable(
                  enabled: !isImporting,
                  child: FilledButton(
                    onPressed: isImporting ? null : onConfirm,
                    child: isImporting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ButtonSpinner(),
                              SizedBox(width: AppSpacing.sm),
                              Flexible(child: Text('Import en cours...')),
                            ],
                          )
                        : Text(
                            importFailed ? 'Réessayer' : 'Confirmer l’import',
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
