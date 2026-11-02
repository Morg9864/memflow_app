import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import 'legal_document_screen.dart';

class LegalAcceptanceScreen extends ConsumerStatefulWidget {
  const LegalAcceptanceScreen({super.key});

  @override
  ConsumerState<LegalAcceptanceScreen> createState() =>
      _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends ConsumerState<LegalAcceptanceScreen> {
  bool _adult = false;
  bool _terms = false;
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    if (!_adult || !_terms || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .acceptCurrentLegalTerms(version: currentTermsVersion);
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'La confirmation n’a pas pu être enregistrée. Vérifie ta connexion et réessaie.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conditions mises à jour')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              shrinkWrap: true,
              children: [
                Text(
                  'Avant de continuer',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Memflow est réservé aux personnes majeures. Confirme ta majorité et accepte les conditions en vigueur pour retrouver ton espace.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    TextButton(
                      onPressed: () => context.push('/legal/terms'),
                      child: const Text('Lire les conditions'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/legal/privacy'),
                      child: const Text('Lire la confidentialité'),
                    ),
                  ],
                ),
                CheckboxListTile(
                  value: _adult,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _adult = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Je confirme avoir au moins 18 ans.'),
                ),
                CheckboxListTile(
                  value: _terms,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _terms = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'J’accepte les conditions d’utilisation et confirme avoir lu la politique de confidentialité.',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonal(
                  style: AppTheme.compactAction,
                  onPressed: _adult && _terms && !_busy ? _accept : null,
                  child: _busy
                      ? const ButtonSpinner()
                      : const Text('Confirmer et continuer'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await ref.read(authServiceProvider).signOut();
                          if (context.mounted) context.go('/auth');
                        },
                  child: const Text('Me déconnecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
