import 'package:memflow/theme/app_icons.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/app/providers.dart';
import 'package:memflow/domain/services/auth_service.dart';
import 'package:memflow/features/auth/auth_screen.dart';
import 'package:memflow/features/auth/reset_password_screen.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuth implements AuthService {
  Object? error;
  Completer<AuthResponse>? pending;
  int signInCalls = 0;
  int updateCalls = 0;

  @override
  Session? get currentSession => null;
  @override
  User? get currentUser => null;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    signInCalls++;
    if (error != null) return Future.error(error!);
    return pending!.future;
  }

  @override
  Future<UserResponse> updatePassword(String password) {
    updateCalls++;
    return Future.error(error!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  _FakeAuth auth, {
  Size size = const Size(360, 800),
  double textScale = 1,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(auth)],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _fill(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'a@b.co');
  await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
}

void main() {
  const sizes = {
    '320x568': (Size(320, 568), 1.0),
    '360x800': (Size(360, 800), 1.0),
    '360x800 x2': (Size(360, 800), 2.0),
  };

  for (final e in sizes.entries) {
    testWidgets('sign-in has no exception at ${e.key}', (tester) async {
      await _pump(
        tester,
        const AuthScreen(),
        _FakeAuth(),
        size: e.value.$1,
        textScale: e.value.$2,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('sign-up has no exception at ${e.key}', (tester) async {
      await _pump(
        tester,
        const AuthScreen(),
        _FakeAuth(),
        size: e.value.$1,
        textScale: e.value.$2,
      );
      await tester.ensureVisible(find.text('Pas de compte ? En créer un'));
      await tester.tap(find.text('Pas de compte ? En créer un'));
      await tester.pump();
      expect(find.text('Créer le compte'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reset has no exception at ${e.key}', (tester) async {
      await _pump(
        tester,
        const ResetPasswordScreen(),
        _FakeAuth(),
        size: e.value.$1,
        textScale: e.value.$2,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keyboard open at 320x568: primary action scrolls into view', (
    tester,
  ) async {
    final auth = _FakeAuth()..error = Exception('boom');
    await _pump(
      tester,
      const AuthScreen(),
      auth,
      size: const Size(320, 568),
      keyboard: 280,
    );
    await _fill(tester);
    final button = find.widgetWithText(FilledButton, 'Se connecter');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    expect(auth.signInCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failure shows a French message, never exception text', (
    tester,
  ) async {
    final auth = _FakeAuth()..error = StateError('secret internals');
    await _pump(tester, const AuthScreen(), auth);
    await _fill(tester);
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Une erreur est survenue. Réessaie.'), findsOneWidget);
    expect(find.textContaining('secret internals'), findsNothing);
    expect(find.byIcon(AppIcons.triangleAlert), findsOneWidget);
  });

  testWidgets('known auth failure is mapped to French', (tester) async {
    final auth = _FakeAuth()
      ..error = const AuthException('Invalid login credentials');
    await _pump(tester, const AuthScreen(), auth);
    await _fill(tester);
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Email ou mot de passe incorrect.'), findsOneWidget);
  });

  testWidgets('primary shows loading and is disabled while submitting', (
    tester,
  ) async {
    final auth = _FakeAuth()..pending = Completer<AuthResponse>();
    await _pump(tester, const AuthScreen(), auth);
    await _fill(tester);
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(auth.signInCalls, 1);
    auth.pending!.completeError(Exception('x'));
    await tester.pump();
    await tester.pump();
  });

  testWidgets('password toggles expose tooltips', (tester) async {
    await _pump(tester, const AuthScreen(), _FakeAuth());
    expect(find.byTooltip('Afficher le mot de passe'), findsOneWidget);
    await tester.tap(find.byTooltip('Afficher le mot de passe'));
    await tester.pump();
    expect(find.byTooltip('Masquer le mot de passe'), findsOneWidget);
  });

  testWidgets('reset: tooltips on both toggles and sanitized error', (
    tester,
  ) async {
    final auth = _FakeAuth()..error = Exception('db password leak');
    await _pump(tester, const ResetPasswordScreen(), auth);
    expect(find.byTooltip('Afficher le mot de passe'), findsNWidgets(2));
    await tester.enterText(find.byType(TextFormField).at(0), 'secret1');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.pump();
    expect(auth.updateCalls, 1);
    expect(find.text('Une erreur est survenue. Réessaie.'), findsOneWidget);
    expect(find.textContaining('leak'), findsNothing);
  });
}
