import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      await authService.updatePassword(_passwordController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe mis à jour !')),
        );
        context.go('/');
      }
    } on AuthException catch (e) {
      _showError(authErrorMessage(e));
    } catch (e) {
      _showError(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  Widget _visibilityButton(bool obscured, VoidCallback onToggle) {
    return IconButton(
      onPressed: onToggle,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
      tooltip: obscured
          ? 'Afficher le mot de passe'
          : 'Masquer le mot de passe',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nouveau mot de passe',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Choisis un nouveau mot de passe pour ton compte.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: _passwordController,
                              enabled: !_busy,
                              obscureText: _obscurePassword,
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                labelText: 'Nouveau mot de passe',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: _visibilityButton(
                                  _obscurePassword,
                                  () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (value) => (value ?? '').length >= 6
                                  ? null
                                  : '6 caractères minimum',
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: _confirmController,
                              enabled: !_busy,
                              obscureText: _obscureConfirm,
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                labelText: 'Confirmer le mot de passe',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: _visibilityButton(
                                  _obscureConfirm,
                                  () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  value == _passwordController.text
                                  ? null
                                  : 'Les mots de passe ne correspondent pas',
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: AppSpacing.lg),
                              AuthErrorText(_error!),
                            ],
                            const SizedBox(height: AppSpacing.xl),
                            Pressable(
                              enabled: !_busy,
                              child: FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const ButtonSpinner()
                                    : const Text('Enregistrer'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
