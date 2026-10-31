import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Lora and Outfit are bundled with 8 faces and used by the theme',
    () async {
      final manifest =
          json.decode(await rootBundle.loadString('FontManifest.json')) as List;
      int faces(String family) =>
          (manifest.firstWhere((e) => e['family'] == family)['fonts'] as List)
              .length;
      expect(faces('Lora'), 4);
      expect(faces('Outfit'), 4);

      final text = AppTheme.light().textTheme;
      expect(text.titleLarge!.fontFamily, 'Lora');
      expect(text.bodyMedium!.fontFamily, 'Outfit');
    },
  );
}
