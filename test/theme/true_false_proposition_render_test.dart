import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/theme/app_theme.dart';

void main() {
  testWidgets('headlineSmall est défini et rend un texte visible', (
    tester,
  ) async {
    late TextStyle? resolved;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              resolved = Theme.of(context).textTheme.headlineSmall;
              return Card(
                child: Text(
                  'Un accident',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              );
            },
          ),
        ),
      ),
    );

    // Le texte de la proposition est présent dans l'arbre.
    expect(find.text('Un accident'), findsOneWidget);

    // headlineSmall ne doit plus être null (sinon la proposition héritait d'un
    // style indéfini et n'apparaissait pas comme attendu).
    expect(resolved, isNotNull);
    expect(resolved!.fontSize, greaterThan(0));
    expect(resolved!.color, isNotNull);
  });
}
