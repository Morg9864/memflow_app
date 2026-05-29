import 'package:csv/csv.dart';

import '../../data/local/database.dart';

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
      const [
        'React & Hooks',
        'Hooks de base',
        'Quel hook React permet d’exécuter un effet de bord après le rendu ?',
        'useEffect',
        'useState',
        'useMemo',
        'useCallback',
        'Un tableau vide [] limite l’effet au montage.',
        'useEffect s’exécute après le rendu et permet de gérer des effets de bord.',
        '1',
        'facile',
        'react|hooks',
        'Cours React',
        'React utilise {{useEffect}} pour exécuter un effet de bord après le rendu.',
        'useEffect|use effect',
      ],
      const [
        'React & Hooks',
        'Hooks de base',
        'Quel hook permet de stocker un état local dans un composant ?',
        'useState',
        'useEffect',
        'useRef',
        'useReducer',
        'Il retourne une valeur et une fonction de mise à jour.',
        'useState permet de déclarer une donnée réactive locale au composant.',
        '1',
        'facile',
        'react|state',
        'Cours React',
        'Le hook {{useState}} permet de stocker un état local.',
        'useState|use state',
      ],
    ];

    return const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
  }

  String exportFlashcards(List<Flashcard> cards, Map<String, String> collectionsById,
      Map<String, String> decksById) {
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

    return const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
  }
}
