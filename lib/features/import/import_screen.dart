import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/ui.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  CsvImportPreview? _preview;
  bool _isBusy = false;
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

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      return;
    }
    setState(() {
      _preview = ref.read(csvImportServiceProvider).parse(bytes);
    });
  }

  Future<void> _downloadTemplate() async {
    final template = ref.read(csvExportServiceProvider).buildTemplate();
    await FilePicker.saveFile(
      dialogTitle: 'Télécharger le template CSV',
      fileName: 'memflow_template.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: utf8.encode(template),
    );
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
    await FilePicker.saveFile(
      dialogTitle: 'Télécharger le prompt CSV Memflow',
      fileName: 'prompt_csv_memflow_neutre.md',
      type: FileType.custom,
      allowedExtensions: const ['md'],
      bytes: utf8.encode(prompt),
    );
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
    if (preview == null || preview.cards.isEmpty) {
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
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (shouldImport != true || !mounted) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      await ref.read(appRepositoryProvider).importCards(preview);
      if (!mounted) return;
      context.go('/');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${preview.cards.length} cartes importées.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      bottomNavigation: AppBottomNav(
        location: GoRouterState.of(context).uri.path,
      ),
      child: ListView(
        children: [
          Row(
            children: [
              Text(
                'Import CSV',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const Spacer(),
              const ThemeToggleButton(),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Accepte les fichiers avec ou sans header, séparés par ; , ou tabulation.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isBusy ? null : _pickFile,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Importer un fichier CSV'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Télécharger le template CSV'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isBusy ? null : _downloadBackup,
              icon: const Icon(Icons.save_alt_rounded),
              label: const Text('Sauvegarder toutes mes cartes'),
            ),
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Format recommandé : collection;deck;question;correct_answer;wrong_answer_1;wrong_answer_2;wrong_answer_3;hint;explanation;level;tags;source;cloze_text;accepted_answers;cloze_answers;cloze_word_bank',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Card(
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              title: Text(
                'Prompt CSV Memflow',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Text(
                'Déplie cette section pour lire, copier ou télécharger le prompt complet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _csvPrompt == null ? null : _copyPrompt,
                        icon: const Icon(Icons.content_copy_rounded),
                        label: const Text('Copier le prompt'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _csvPrompt == null ? null : _downloadPrompt,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Télécharger le .md'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 360),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: _csvPrompt == null
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          child: SelectableText(
                            _csvPrompt!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (_preview == null)
            const EmptyState(
              title: 'Aucun fichier chargé',
              message:
                  'Charge un fichier pour prévisualiser les cartes détectées et les erreurs.',
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prévisualisation',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    Text('${_preview!.cards.length} cartes détectées'),
                    Text('${_preview!.issues.length} lignes invalides'),
                    Text(
                      'Séparateur : ${_preview!.delimiter == '\t' ? 'tabulation' : _preview!.delimiter}',
                    ),
                    Text('Header : ${_preview!.withHeader ? 'oui' : 'non'}'),
                    const SizedBox(height: 18),
                    if (_preview!.issues.isNotEmpty) ...[
                      const SectionLabel('Erreurs'),
                      const SizedBox(height: 10),
                      for (final issue in _preview!.issues)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Ligne ${issue.rowNumber} : ${issue.message}',
                          ),
                        ),
                      const SizedBox(height: 14),
                    ],
                    if (_preview!.cards.isNotEmpty) ...[
                      const SectionLabel('Aperçu'),
                      const SizedBox(height: 10),
                      for (final card in _preview!.cards.take(4))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${card.collection} • ${card.deck}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  card.question,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _isBusy || _preview!.cards.isEmpty
                          ? null
                          : _confirmImport,
                      child: Text(
                        _isBusy ? 'Import en cours...' : 'Confirmer l’import',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
