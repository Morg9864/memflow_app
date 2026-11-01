import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memflow/app/providers.dart';
import 'package:memflow/data/repositories/app_repository.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/csv_import_service.dart';
import 'package:memflow/features/import/import_screen.dart';
import 'package:memflow/theme/app_theme.dart';
import 'package:memflow/widgets/ui.dart';

class _FakeParser implements CsvImportService {
  _FakeParser(this.onParse);
  final CsvImportPreview Function() onParse;

  @override
  CsvImportPreview parse(List<int> bytes) => onParse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepository implements AppRepository {
  Object? failWith;
  int calls = 0;

  @override
  Future<void> importCards(CsvImportPreview preview) async {
    calls++;
    final error = failWith;
    if (error != null) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CsvImportCardDraft _card(String q) => CsvImportCardDraft(
  collection: 'Bio',
  deck: 'Cellule',
  question: q,
  correctAnswer: 'a',
  wrongAnswers: const [],
  hint: null,
  explanation: null,
  level: 1,
  tags: const [],
  source: null,
  clozeText: null,
  clozeAnswers: const [],
  clozeWordBank: const [],
  acceptedAnswers: const [],
  allowedTestModes: const [],
);

CsvImportPreview _preview({int cards = 2, int issues = 1}) => CsvImportPreview(
  cards: [for (var i = 0; i < cards; i++) _card('Question numéro $i ?')],
  issues: [
    for (var i = 0; i < issues; i++)
      CsvImportIssue(rowNumber: i + 2, message: 'colonne manquante $i'),
  ],
  delimiter: ';',
  withHeader: true,
);

Future<FilePickerResult?> _picked() async => FilePickerResult([
  PlatformFile(
    name: 'cartes.csv',
    size: 3,
    bytes: Uint8List.fromList([1, 2, 3]),
  ),
]);

Future<FilePickerResult?> _pickedNoBytes() async =>
    FilePickerResult([PlatformFile(name: 'cartes.csv', size: 0)]);

Future<_FakeRepository> _pump(
  WidgetTester tester, {
  CsvImportPreview Function()? parse,
  Future<FilePickerResult?> Function() pick = _picked,
  Size size = const Size(360, 2400),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final repo = _FakeRepository();
  final List<Override> overrides = [
    appRepositoryProvider.overrideWithValue(repo),
    csvImportServiceProvider.overrideWithValue(
      _FakeParser(parse ?? () => _preview()),
    ),
  ];
  final router = GoRouter(
    initialLocation: '/import',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME-SCREEN')),
      ),
      GoRoute(
        path: '/import',
        builder: (_, _) => ImportScreen(pickFiles: pick),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _choose(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Importer un fichier CSV'));
  await tester.pump();
  await tester.tap(find.text('Importer un fichier CSV'));
  await tester.pumpAndSettle();
}

Finder get _confirm => find.widgetWithText(FilledButton, 'Confirmer l’import');

Future<void> _tapConfirmAndAccept(WidgetTester tester) async {
  final button = find.descendant(
    of: find.byType(Pressable).last,
    matching: find.byType(FilledButton),
  );
  await tester.tap(button);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Restaurer'));
  await tester.pumpAndSettle();
}

// The prompt asset spinner never settles under fake async: pump fixed time.
Future<void> _expand(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('idle: primary card, muted hint, collapsed advanced options', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Import CSV'), findsOneWidget);
    expect(find.text('Importer un fichier CSV'), findsOneWidget);
    expect(find.textContaining('Aucun fichier chargé.'), findsOneWidget);
    expect(find.text('Options avancées'), findsOneWidget);
    expect(find.text('Prévisualisation'), findsNothing);
    expect(find.text('Télécharger le template CSV'), findsNothing);
    expect(find.byType(EmptyState), findsNothing);
  });

  testWidgets('content stays within the form column on a tablet', (
    tester,
  ) async {
    await _pump(tester, size: const Size(880, 1408));
    expect(
      tester.getSize(find.byType(ListView).first).width,
      lessThanOrEqualTo(AppTheme.formMaxWidth),
    );
  });

  testWidgets('preview shows summary, errors and sample', (tester) async {
    await _pump(tester);
    await _choose(tester);
    expect(find.text('Prévisualisation'), findsOneWidget);
    expect(find.text('cartes.csv'), findsOneWidget);
    expect(find.text('2 cartes détectées'), findsOneWidget);
    expect(find.text('1 ligne invalide'), findsOneWidget);
    expect(find.text('Ligne 2 : colonne manquante 0'), findsOneWidget);
    expect(find.text('APERÇU'), findsOneWidget);
    expect(find.text('Question numéro 0 ?'), findsOneWidget);
    expect(_confirm, findsOneWidget);
  });

  testWidgets('issues are capped at 20 with a count of the rest', (
    tester,
  ) async {
    await _pump(tester, parse: () => _preview(issues: 25));
    await _choose(tester);
    expect(find.textContaining('Ligne '), findsNWidgets(20));
    expect(find.text('et 5 autres lignes'), findsOneWidget);
    expect(find.text('25 lignes invalides'), findsOneWidget);
  });

  testWidgets('zero valid cards: error message and no confirm button', (
    tester,
  ) async {
    await _pump(tester, parse: () => _preview(cards: 0, issues: 2));
    await _choose(tester);
    expect(find.text('Aucune carte exploitable'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.textContaining('Confirmer'), findsNothing);
    expect(find.text('APERÇU'), findsNothing);
  });

  testWidgets('parse failure shows the unreadable message', (tester) async {
    await _pump(tester, parse: () => throw const FormatException('boom'));
    await _choose(tester);
    expect(find.text('Impossible de lire ce fichier.'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
    expect(find.text('Prévisualisation'), findsNothing);
  });

  testWidgets('file without bytes shows the unreadable message', (
    tester,
  ) async {
    await _pump(tester, pick: _pickedNoBytes);
    await _choose(tester);
    expect(find.text('Impossible de lire ce fichier.'), findsOneWidget);
  });

  testWidgets('cancelled picker stays idle', (tester) async {
    await _pump(tester, pick: () async => null);
    await _choose(tester);
    expect(find.textContaining('Aucun fichier chargé.'), findsOneWidget);
  });

  testWidgets('importCards failure: inline error, retry works', (tester) async {
    final repo = await _pump(tester);
    repo.failWith = Exception('SECRET-DB-DETAIL');
    await _choose(tester);
    await _tapConfirmAndAccept(tester);
    expect(repo.calls, 1);
    expect(find.text('L’import a échoué.'), findsOneWidget);
    expect(find.textContaining('SECRET-DB-DETAIL'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
    final retry = find.widgetWithText(FilledButton, 'Réessayer');
    expect(retry, findsOneWidget);
    expect(tester.widget<FilledButton>(retry).onPressed, isNotNull);

    repo.failWith = null;
    await _tapConfirmAndAccept(tester);
    expect(repo.calls, 2);
    expect(find.text('HOME-SCREEN'), findsOneWidget);
  });

  testWidgets('success: snackbar and navigation to /', (tester) async {
    final repo = await _pump(tester);
    await _choose(tester);
    await _tapConfirmAndAccept(tester);
    expect(repo.calls, 1);
    expect(find.text('HOME-SCREEN'), findsOneWidget);
    expect(find.text('2 cartes importées.'), findsOneWidget);
  });

  testWidgets('advanced section holds every secondary action', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Options avancées'));
    await _expand(tester);
    for (final label in [
      'Télécharger le template CSV',
      'Sauvegarder toutes mes cartes',
      'Prompt CSV Memflow',
      'Copier le prompt',
      'Télécharger le .md',
    ]) {
      expect(
        find.text(label, skipOffstage: false),
        findsOneWidget,
        reason: label,
      );
    }
    expect(find.textContaining('Format recommandé'), findsOneWidget);
  });

  for (final (name, size, scale) in [
    ('320x568', const Size(320, 568), 1.0),
    ('360x800', const Size(360, 800), 1.0),
    ('360x800 @2.0', const Size(360, 800), 2.0),
  ]) {
    testWidgets('no exceptions at $name (idle, preview, expanded)', (
      tester,
    ) async {
      await _pump(
        tester,
        size: size,
        textScale: scale,
        parse: () => _preview(issues: 25),
      );
      expect(tester.takeException(), isNull);
      await _choose(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Prévisualisation'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Options avancées'), 200);
      await tester.tap(find.text('Options avancées'));
      await _expand(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
