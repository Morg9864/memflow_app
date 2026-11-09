import 'package:memflow/theme/app_icons.dart';
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
  bool _isImporting = false;
  bool _readFailed = false;
  bool _importFailed = false;
  List<String> _fileNames = const [];
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
                allowMultiple: true,
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
    final files = result.files;
    final fileNames = files.map((file) => file.name).toList();
    final parser = ref.read(csvImportServiceProvider);
    final previews = <({String name, CsvImportPreview preview})>[];
    final unreadable = <String>[];
    for (final file in files) {
      final bytes = file.bytes;
      if (bytes == null) {
        unreadable.add(file.name);
        continue;
      }
      try {
        previews.add((name: file.name, preview: parser.parse(bytes)));
      } catch (_) {
        unreadable.add(file.name);
      }
    }
    final isSingleUnreadable = files.length == 1 && unreadable.isNotEmpty;
    final preview = isSingleUnreadable
        ? null
        : CsvImportPreview(
            cards: [for (final entry in previews) ...entry.preview.cards],
            issues: [
              for (final entry in previews)
                for (final issue in entry.preview.issues)
                  CsvImportIssue(
                    rowNumber: issue.rowNumber,
                    message: issue.message,
                    sourceName: files.length > 1 ? entry.name : null,
                  ),
              for (final name in unreadable)
                CsvImportIssue(
                  rowNumber: 0,
                  message: 'Impossible de lire ce fichier.',
                  sourceName: files.length > 1 ? name : null,
                ),
            ],
            delimiter: previews.length == 1
                ? previews.single.preview.delimiter
                : 'multi',
            withHeader:
                previews.length == 1 && previews.single.preview.withHeader,
          );
    setState(() {
      _preview = preview;
      _fileNames = fileNames;
      _readFailed = isSingleUnreadable;
      _importFailed = false;
    });
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
        SnackBar(
          content: Text(
            preview.cards.length == 1
                ? '1 carte importée.'
                : '${preview.cards.length} cartes importées.',
          ),
        ),
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
        fileNames: _fileNames,
        isImporting: _isImporting,
        importFailed: _importFailed,
        onConfirm: _confirmImport,
      );
    }
    return AppScaffold(
      maxContentWidth: AppTheme.formMaxWidth,
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
                      const IconTile(icon: AppIcons.fileUp),
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
                    'Sélectionne un ou plusieurs fichiers CSV ou TXT, séparés par ; , ou tabulation, avec ou sans ligne d’en-tête.',
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
                              icon: const Icon(AppIcons.fileUp),
                              label: const Text('Choisir d’autres fichiers CSV'),
                            )
                          : FilledButton.icon(
                              onPressed: _isImporting ? null : _pickFile,
                              icon: const Icon(AppIcons.fileUp),
                              label: const Text('Choisir des fichiers CSV'),
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
              expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
                  ? AnimationStyle.noAnimation
                  : null,
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
                  icon: const Icon(AppIcons.copy),
                  label: const Text('Copier le prompt'),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonalIcon(
                  style: AppTheme.secondaryAction,
                  onPressed: _csvPrompt == null ? null : _downloadPrompt,
                  icon: const Icon(AppIcons.download),
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
          const Icon(AppIcons.triangleAlert, color: AppColors.error),
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
    required this.fileNames,
    required this.isImporting,
    required this.importFailed,
    required this.onConfirm,
  });

  static const _maxIssues = 20;

  final CsvImportPreview preview;
  final List<String> fileNames;
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
            if (fileNames.length > 1) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${fileNames.length} fichiers sélectionnés',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                '${fileNames.take(5).join(', ')}${fileNames.length > 5 ? ', …' : ''}',
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ] else if (fileNames.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                fileNames.single,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _SummaryRow(
              icon: AppIcons.circleCheck,
              text: preview.cards.length > 1
                  ? '${preview.cards.length} cartes détectées'
                  : '${preview.cards.length} carte détectée',
            ),
            _SummaryRow(
              icon: hasIssues ? AppIcons.triangleAlert : AppIcons.circleCheck,
              color: hasIssues ? AppColors.error : null,
              text: issues.length > 1
                  ? '${issues.length} lignes invalides'
                  : '${issues.length} ligne invalide',
            ),
            if (fileNames.length > 1)
              Text(
                'Les fichiers sont regroupés dans un seul import.',
                style: theme.textTheme.bodySmall,
              )
            else
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
                    'Aucune carte n’a pu être lue dans ${fileNames.length > 1 ? 'ces fichiers' : 'ce fichier'}. Vérifie le séparateur et que chaque ligne contient au moins une question et sa bonne réponse.',
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
                    issue.sourceName == null
                        ? 'Ligne ${issue.rowNumber} : ${issue.message}'
                        : issue.rowNumber == 0
                        ? '${issue.sourceName} : ${issue.message}'
                        : '${issue.sourceName} · ligne ${issue.rowNumber} : ${issue.message}',
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
