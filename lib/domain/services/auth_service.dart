import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase GoTrue auth used by the UI and the session
/// controller. Keeps Supabase-specific calls in one place.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  User? get currentUser => _auth.currentUser;

  Session? get currentSession => _auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> updateDisplayName(String name) {
    return _auth.updateUser(
      UserAttributes(data: {'display_name': name}),
    );
  }

  Future<void> updateEmail(String email) {
    return _auth.updateUser(UserAttributes(email: email));
  }

  Future<void> updatePassword(String password) {
    return _auth.updateUser(UserAttributes(password: password));
  }

  Future<void> resetPasswordForEmail(String email, {String? redirectTo}) {
    return _auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }
}
