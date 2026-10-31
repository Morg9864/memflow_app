import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/theme/app_theme.dart';

void main() {
  test('palette values are exact', () {
    expect(AppColors.background, const Color(0xFFFDF9F4));
    expect(AppColors.surface, const Color(0xFFFFFFFF));
    expect(AppColors.surfaceSoft, const Color(0xFFFBF6EF));
    expect(AppColors.border, const Color(0xFFE8DED3));
    expect(AppColors.text, const Color(0xFF1E1715));
    expect(AppColors.muted, const Color(0xFF7C6C61));
    expect(AppColors.primary, const Color(0xFFDE7935));
    expect(AppColors.primarySoft, const Color(0xFFFCE9DC));
    expect(AppColors.surfaceHigh, const Color(0xFFF1E7DC));
    expect(AppColors.error, const Color(0xFFD94A3A));
    expect(AppColors.resultGood, const Color(0xFF4D9461));
    expect(AppColors.resultGoodText, const Color(0xFF245433));
    expect(AppColors.resultGoodSoft, const Color(0xFFEAF3E7));
    expect(AppColors.resultBad, const Color(0xFFD94A3A));
    expect(AppColors.resultBadText, const Color(0xFF8E2F24));
    expect(AppColors.resultBadSoft, const Color(0xFFFBE7E4));
    expect(AppColors.ratingHard, const Color(0xFFE8792F));
    expect(AppColors.ratingEasy, const Color(0xFF4D79B5));
    expect(AppColors.ratingEasySoft, const Color(0xFFEAF0F3));
  });

  testWidgets('all text slots are fully defined', (tester) async {
    late TextTheme t;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (c) {
            t = Theme.of(c).textTheme;
            return const SizedBox();
          },
        ),
      ),
    );
    final slots = {
      'displayLarge': t.displayLarge,
      'displayMedium': t.displayMedium,
      'displaySmall': t.displaySmall,
      'headlineLarge': t.headlineLarge,
      'headlineMedium': t.headlineMedium,
      'headlineSmall': t.headlineSmall,
      'titleLarge': t.titleLarge,
      'titleMedium': t.titleMedium,
      'titleSmall': t.titleSmall,
      'bodyLarge': t.bodyLarge,
      'bodyMedium': t.bodyMedium,
      'bodySmall': t.bodySmall,
      'labelLarge': t.labelLarge,
      'labelMedium': t.labelMedium,
      'labelSmall': t.labelSmall,
    };
    expect(slots.length, 15);
    slots.forEach((name, s) {
      expect(s, isNotNull, reason: name);
      expect(['Lora', 'Outfit'], contains(s!.fontFamily), reason: name);
      expect(s.color, isNotNull, reason: name);
      expect(s.color, isNot(Colors.white), reason: name);
      expect(s.fontSize, greaterThanOrEqualTo(12), reason: name);
    });
  });

  testWidgets('filled and tonal buttons keep their own colours', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              FilledButton(
                key: const Key('f'),
                onPressed: () {},
                child: const Text('F'),
              ),
              FilledButton.tonal(
                key: const Key('t'),
                onPressed: () {},
                child: const Text('T'),
              ),
            ],
          ),
        ),
      ),
    );
    Material materialOf(String k) => tester.widget<Material>(
      find.descendant(of: find.byKey(Key(k)), matching: find.byType(Material)),
    );
    expect(materialOf('f').color, AppColors.primary);
    expect(materialOf('t').color, AppColors.primarySoft);
    final style = tester
        .widget<DefaultTextStyle>(
          find
              .descendant(
                of: find.byKey(const Key('t')),
                matching: find.byType(DefaultTextStyle),
              )
              .first,
        )
        .style;
    expect(style.color, AppColors.text);
  });

  test('no literal Color(0x outside the theme', () {
    final offenders = <String>[];
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      if (e.path.endsWith('.g.dart') ||
          e.path.endsWith('lib/theme/app_theme.dart')) {
        continue;
      }
      if (e.readAsStringSync().contains('Color(0x')) offenders.add(e.path);
    }
    expect(offenders, isEmpty);
  });
}
