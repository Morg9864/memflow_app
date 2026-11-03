import 'dart:io';

import '../../../lib/domain/models/models.dart';
import '../../../lib/domain/services/card_mode_service.dart';
import '../../../lib/domain/services/csv_import_service.dart';

void main() {
  final file = File('docs/user-guide/demo/data/memflow_documentation_demo.csv');
  if (!file.existsSync()) {
    stderr.writeln('CSV absent. Lancez d’abord generate_demo_csv.py.');
    exitCode = 1;
    return;
  }

  final service = CsvImportService(const CardModeService());
  final preview = service.parse(file.readAsBytesSync());
  final modes = {
    for (final mode in TestMode.values)
      mode.label: preview.cards
          .where((card) => card.allowedTestModes.contains(mode))
          .length,
  };

  stdout.writeln('Cartes reconnues : ${preview.cards.length}');
  stdout.writeln('Erreurs d’import : ${preview.issues.length}');
  stdout.writeln('Modes disponibles : $modes');
  if (preview.cards.length != 153 || preview.issues.isNotEmpty) {
    for (final issue in preview.issues.take(10)) {
      stderr.writeln('Ligne ${issue.rowNumber} : ${issue.message}');
    }
    exitCode = 1;
  }
}
