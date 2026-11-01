import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../app/session_card_limit_controller.dart';
import '../../app/providers.dart';
import '../../widgets/ui.dart';
import 'settings_row.dart';

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
      maxContentWidth: AppTheme.formMaxWidth,
      child: ListView(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => popOrGo(context, '/profile'),
                tooltip: 'Retour',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Paramètres',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SettingsGroup(
            label: 'Mon compte',
            children: [
              SettingsRow(
                icon: Icons.badge_outlined,
                title: 'Nom d\'affichage',
                subtitle: displayName ?? '—',
                trailing: const _EditIcon(),
                onTap: () =>
                    _showEditNameDialog(context, ref, displayName ?? ''),
              ),
              SettingsRow(
                icon: Icons.mail_outline_rounded,
                title: 'Adresse email',
                subtitle: user.email ?? '—',
                trailing: const _EditIcon(),
                onTap: () =>
                    _showEditEmailDialog(context, ref, user.email ?? ''),
              ),
              SettingsRow(
                icon: Icons.lock_outline_rounded,
                title: 'Mot de passe',
                subtitle: '••••••••',
                trailing: const _EditIcon(),
                onTap: () => _showEditPasswordDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SettingsGroup(
            label: 'Révision',
            children: [
              SettingsRow(
                icon: Icons.style_outlined,
                title: 'Cartes par session',
                subtitle: '$sessionCardLimit cartes max par session',
                trailing: const _EditIcon(),
                onTap: () => _showEditSessionCardLimitDialog(
                  context,
                  ref,
                  sessionCardLimit,
                ),
              ),
            ],
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
    final authService = ref.read(authServiceProvider);

    await showDialog<void>(
      context: context,
      builder: (ctx) => _EditDialog(
        title: 'Modifier le nom',
        initialText: current,
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
    final authService = ref.read(authServiceProvider);

    await showDialog<void>(
      context: context,
      builder: (ctx) => _EditDialog(
        title: 'Modifier l\'email',
        initialText: current,
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
    final authService = ref.read(authServiceProvider);

    await showDialog<void>(
      context: context,
      builder: (ctx) => _PasswordDialog(
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
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _SessionCardLimitDialog(initial: current),
    );
    if (result != null) {
      await ref.read(sessionCardLimitProvider.notifier).setLimit(result);
    }
  }
}

class _EditIcon extends StatelessWidget {
  const _EditIcon();

  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.edit_outlined, semanticLabel: 'Modifier');
}

/// Les dialogues possèdent leurs contrôleurs : ils sont libérés avec le
/// `State`, c'est-à-dire après la fin de l'animation de fermeture.
class _EditDialog extends StatefulWidget {
  const _EditDialog({
    required this.title,
    required this.initialText,
    required this.label,
    required this.onSave,
    this.keyboardType,
    this.confirmNote,
    this.successMessage,
  });

  final String title;
  final String initialText;
  final String label;
  final Future<void> Function(String value) onSave;
  final TextInputType? keyboardType;
  final String? confirmNote;
  final String? successMessage;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            keyboardType: widget.keyboardType,
            textInputAction: TextInputAction.done,
            onSubmitted: _loading ? null : (_) => _submit(),
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.resultBadText),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.tonal(
          style: AppTheme.compactAction,
          onPressed: _loading ? null : _submit,
          child: _loading ? const ButtonSpinner() : const Text('Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
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
  const _PasswordDialog({required this.onSave});

  final Future<void> Function(String value) onSave;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _SessionCardLimitDialog extends StatefulWidget {
  const _SessionCardLimitDialog({required this.initial});

  final int initial;

  @override
  State<_SessionCardLimitDialog> createState() =>
      _SessionCardLimitDialogState();
}

class _SessionCardLimitDialogState extends State<_SessionCardLimitDialog> {
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
      title: const Text('Cartes par session'),
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

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le mot de passe'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
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
            controller: _confirmController,
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.resultBadText),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.tonal(
          style: AppTheme.compactAction,
          onPressed: _loading ? null : _submit,
          child: _loading ? const ButtonSpinner() : const Text('Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final password = _controller.text;
    final confirm = _confirmController.text;
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
