import 'package:memflow/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';

/// User-facing text for a failed auth call. Raw exception text never reaches
/// the screen: known Supabase failures get a French message, the rest a
/// generic one.
String authErrorMessage(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (message.contains('already registered')) {
      return 'Un compte existe déjà avec cet email.';
    }
    if (message.contains('email not confirmed')) {
      return 'Confirme ton email avant de te connecter.';
    }
    if (message.contains('same password') ||
        message.contains('different from the old')) {
      return 'Choisis un mot de passe différent de l’ancien.';
    }
  }
  return 'Une erreur est survenue. Réessaie.';
}

/// Inline form error: icon + text (never colour alone), announced politely.
class AuthErrorText extends StatelessWidget {
  const AuthErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const color = AppColors.resultBadText;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(AppIcons.triangleAlert, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
