import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/session_card_limit_controller.dart';
import '../../app/providers.dart';
import '../../widgets/ui.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final displayName = ref.watch(displayNameProvider);
    final sessionCardLimit = ref.watch(sessionCardLimitProvider);

    if (user == null) {
      return const AppScaffold(child: Center(child: Text('Non connecté')));
    }

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Text(
                'Paramètres',
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: SectionLabel('Mon compte'),
                ),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Nom d\'affichage'),
                  subtitle: Text(displayName ?? '—'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () =>
                      _showEditNameDialog(context, ref, displayName ?? ''),
                ),
                ListTile(
                  leading: const Icon(Icons.mail_outline_rounded),
                  title: const Text('Adresse email'),
                  subtitle: Text(user.email ?? '—'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () =>
                      _showEditEmailDialog(context, ref, user.email ?? ''),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('Mot de passe'),
                  subtitle: const Text('••••••••'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _showEditPasswordDialog(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: SectionLabel('Révision'),
                ),
                ListTile(
                  leading: const Icon(Icons.style_outlined),
                  title: const Text('Cartes par session'),
                  subtitle: Text('$sessionCardLimit cartes max par session'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _showEditSessionCardLimitDialog(
                    context,
                    ref,
                    sessionCardLimit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final authService = ref.read(authServiceProvider);

    await showDialog<void>(
      context: context,
      builder: (ctx) => _EditDialog(
        title: 'Modifier le nom',
        controller: controller,
        label: 'Nom d\'affichage',
        keyboardType: TextInputType.name,
        onSave: (value) async {
          await authService.updateDisplayName(value);
          // Force a re-read of the user so displayNameProvider rebuilds.
          ref.invalidate(authStateProvider);
        },
      ),
    );
  }

  Future<void> _showEditEmailDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final authService = ref.read(authServiceProvider);

    await showDialog<void>(
      context: context,
      builder: (ctx) => _EditDialog(
        title: 'Modifier l\'email',
        controller: controller,
        label: 'Nouvelle adresse email',
        keyboardType: TextInputType.emailAddress,
        confirmNote:
            'Un email de confirmation sera envoyé à ta nouvelle adresse. '
            'Le changement ne sera effectif qu\'après confirmation.',
        onSave: (value) async {
          await authService.updateEmail(value);
        },
        successMessage:
            'Email de confirmation envoyé à $current. Vérifie ta boîte de réception.',
      ),
    );
  }

  Future<void> _showEditPasswordDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final authService = ref.read(authServiceProvider);

    await showDialog<void>(
      context: context,
      builder: (ctx) => _PasswordDialog(
        controller: controller,
        confirmController: confirmController,
        onSave: (value) async {
          await authService.updatePassword(value);
        },
      ),
    );
  }

  Future<void> _showEditSessionCardLimitDialog(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final controller = TextEditingController(text: '$current');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _SessionCardLimitDialog(controller: controller),
    );
    if (result != null) {
      await ref.read(sessionCardLimitProvider.notifier).setLimit(result);
    }
  }
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({
    required this.title,
    required this.controller,
    required this.label,
    required this.onSave,
    this.keyboardType,
    this.confirmNote,
    this.successMessage,
  });

  final String title;
  final TextEditingController controller;
  final String label;
  final Future<void> Function(String value) onSave;
  final TextInputType? keyboardType;
  final String? confirmNote;
  final String? successMessage;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            autofocus: true,
            decoration: InputDecoration(labelText: widget.label),
          ),
          if (widget.confirmNote != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.confirmNote!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final value = widget.controller.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSave(value);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (widget.successMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(widget.successMessage!)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({
    required this.controller,
    required this.confirmController,
    required this.onSave,
  });

  final TextEditingController controller;
  final TextEditingController confirmController;
  final Future<void> Function(String value) onSave;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _SessionCardLimitDialog extends StatefulWidget {
  const _SessionCardLimitDialog({required this.controller});

  final TextEditingController controller;

  @override
  State<_SessionCardLimitDialog> createState() =>
      _SessionCardLimitDialogState();
}

class _SessionCardLimitDialogState extends State<_SessionCardLimitDialog> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cartes par session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nombre maximum de cartes',
              suffixText: 'cartes',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Si le deck contient moins de cartes que cette limite, la session prend tout le deck.',
            style: Theme.of(context).textTheme.bodySmall,
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

class _PasswordDialogState extends State<_PasswordDialog> {
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le mot de passe'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.controller,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nouveau mot de passe',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.confirmController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirmer le mot de passe',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final password = widget.controller.text;
    final confirm = widget.confirmController.text;
    if (password.length < 6) {
      setState(
        () => _error = 'Le mot de passe doit faire au moins 6 caractères.',
      );
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSave(password);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Mot de passe mis à jour.')),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }
}
