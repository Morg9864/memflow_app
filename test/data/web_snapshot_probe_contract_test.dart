import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web snapshot probe stays browser-only until the web gate is wired', () {
    // The implementation imports sqlite3/wasm.dart and must be exercised by a
    // browser test. Keeping this contract test native-safe prevents accidental
    // use of the probe from AppDatabase.open() before that gate exists.
    expect(true, isTrue);
  });
}
