import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/ui.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _busy = false;

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

  @override
  Widget build(BuildContext context) {
    final themePreference = ref.watch(themeControllerProvider);
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
                  Text('Morgan', style: Theme.of(context).textTheme.titleLarge),
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
                  const Text('1.0.0+1'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
