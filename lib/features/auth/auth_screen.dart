import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import '../../domain/services/auth_service.dart';
import '../../widgets/ui.dart';

enum _AuthMode { signIn, signUp }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  AuthService get _authService => ref.read(authServiceProvider)!;

  bool get _isSignUp => _mode == _AuthMode.signUp;

  void _toggleMode() {
    setState(() => _mode = _isSignUp ? _AuthMode.signIn : _AuthMode.signUp);
  }

  /// Runs an auth action with shared busy/error handling. Returns true on
  /// success. Navigation happens via the router's auth redirect.
  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Une erreur est survenue. Réessaie.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    return false;
  }

  Future<void> _submitEmailPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isSignUp) {
      final ok = await _run(() async {
        final response = await _authService.signUpWithPassword(
          email: email,
          password: password,
          displayName: _nameController.text.trim(),
        );
        // When email confirmation is enabled, no session is returned yet.
        if (response.session == null && mounted) {
          _showMessage('Compte créé. Vérifie ta boîte mail pour confirmer.');
        }
      });
      if (ok) {
        return;
      }
    } else {
      await _run(() => _authService.signInWithPassword(
            email: email,
            password: password,
          ));
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Image.asset(
                        'memflow.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'MemFlow',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp
                        ? 'Crée ton compte pour synchroniser tes cartes.'
                        : 'Connecte-toi pour retrouver tes cartes.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isSignUp) ...[
                            TextFormField(
                              controller: _nameController,
                              enabled: !_busy,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Nom',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) => (value ?? '').trim().isNotEmpty
                                  ? null
                                  : 'Saisis un nom',
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _emailController,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: (value) => _isValidEmail((value ?? '').trim())
                                ? null
                                : 'Email invalide',
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !_busy,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                tooltip: _obscurePassword
                                    ? 'Afficher le mot de passe'
                                    : 'Masquer le mot de passe',
                              ),
                            ),
                            validator: (value) => (value ?? '').length >= 6
                                ? null
                                : '6 caractères minimum',
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _busy ? null : _submitEmailPassword,
                            child: _busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(_isSignUp ? 'Créer le compte' : 'Se connecter'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _busy ? null : _toggleMode,
                    child: Text(
                      _isSignUp
                          ? 'Déjà un compte ? Se connecter'
                          : 'Pas de compte ? En créer un',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
