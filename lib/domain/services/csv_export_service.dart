import 'package:csv/csv.dart';

import '../models/models.dart';

class CsvExportService {
  const CsvExportService();

  String buildTemplate() {
    final rows = [
      const [
        'collection',
        'deck',
        'question',
        'correct_answer',
        'wrong_answer_1',
        'wrong_answer_2',
        'wrong_answer_3',
        'hint',
        'explanation',
        'level',
        'difficulty',
        'tags',
        'source',
        'cloze_text',
        'accepted_answers',
      ],
    ];

    return Csv(fieldDelimiter: ';').encode(rows);
  }

  String exportFlashcards(
    List<FlashcardRecord> cards,
    Map<String, String> collectionsById,
    Map<String, String> decksById,
  ) {
    final rows = <List<String>>[
      const [
        'collection',
        'deck',
        'question',
        'correct_answer',
        'wrong_answer_1',
        'wrong_answer_2',
        'wrong_answer_3',
        'hint',
        'explanation',
        'level',
        'difficulty',
        'tags',
        'source',
        'cloze_text',
        'accepted_answers',
      ],
    ];

    for (final card in cards) {
      final wrongAnswers = card.wrongAnswers;
      rows.add([
        collectionsById[card.collectionId] ?? '',
        decksById[card.deckId] ?? '',
        card.question,
        card.correctAnswer,
        wrongAnswers.isNotEmpty ? wrongAnswers[0] : '',
        wrongAnswers.length > 1 ? wrongAnswers[1] : '',
        wrongAnswers.length > 2 ? wrongAnswers[2] : '',
        card.hint ?? '',
        card.explanation ?? '',
        card.level.toString(),
        card.difficulty?.name ?? '',
        card.tags.join('|'),
        card.source ?? '',
        card.clozeText ?? '',
        card.acceptedAnswers.join('|'),
      ]);
    }

    return Csv(fieldDelimiter: ';').encode(rows);
  }
}
