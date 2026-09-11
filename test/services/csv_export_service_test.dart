import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/card_mode_service.dart';
import 'package:memflow/domain/services/csv_export_service.dart';
import 'package:memflow/domain/services/csv_import_service.dart';

void main() {
  const service = CsvExportService();

  test('backup export uses the import-compatible complete card format', () {
    final card = FlashcardRecord(
      id: 'card-1',
      collectionId: 'collection-1',
      deckId: 'deck-1',
      question: 'Question; avec séparateur',
      correctAnswer: 'Bonne réponse',
      answer: 'Bonne réponse',
      wrongAnswers: const ['A', 'B', 'C'],
      hint: 'Indice',
      explanation: 'Explication',
      currentTestMode: TestMode.multipleChoice,
      allowedTestModes: const [TestMode.multipleChoice],
      lastTestMode: null,
      modeHistory: const [TestMode.multipleChoice],
      clozeText: null,
      clozeAnswers: const [],
      clozeWordBank: const [],
      acceptedAnswers: const ['Bonne réponse'],
      source: 'Cours',
      difficulty: DeckDifficulty.facile,
      level: 2,
      tags: const ['tag1', 'tag2'],
      dueAt: DateTime(2026, 1, 1),
      lastReviewedAt: DateTime(2025, 12, 1),
      intervalDays: 4,
      easeFactor: 2.5,
      repetitions: 3,
      lapses: 1,
      mastered: true,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 12, 1),
    );

    final csv = service.exportFlashcards(
      [card],
      const {'collection-1': 'Collection'},
      const {'deck-1': 'Deck'},
    );
    final rows = const CsvDecoder(fieldDelimiter: ';').convert(csv);

    expect(rows.first, CsvExportService.header);
    expect(rows, hasLength(2));
    expect(rows[1][0], 'Collection');
    expect(rows[1][1], 'Deck');
    expect(rows[1][2], card.question);
    expect(rows[1][13], 'Bonne réponse');
    expect(rows[1][14], isEmpty);
    expect(utf8.decode(utf8.encode(csv)), csv);

    final restored = CsvImportService(
      const CardModeService(),
    ).parse(utf8.encode(csv));
    expect(restored.issues, isEmpty);
    expect(restored.cards.single.question, card.question);
    expect(restored.cards.single.correctAnswer, card.correctAnswer);
    expect(restored.cards.single.tags, card.tags);
  });

  test('template and backup share exactly the same header', () {
    final template = const CsvDecoder(
      fieldDelimiter: ';',
    ).convert(service.buildTemplate());

    expect(template.single, CsvExportService.header);
  });
}
