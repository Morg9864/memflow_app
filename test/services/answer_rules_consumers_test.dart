import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/card_mode_service.dart';
import 'package:memflow/domain/services/csv_import_service.dart';
import 'package:memflow/features/study/study_controller.dart';

void main() {
  const modes = CardModeService();
  final importer = CsvImportService(modes);
  final study = StudyRules();

  CsvImportPreview importCloze({
    required String text,
    required List<String> answers,
    required List<String> bank,
    List<String> accepted = const [],
  }) {
    final row = [
      'Langues',
      'Vocabulaire',
      'Compléter',
      answers.first,
      'A',
      'B',
      'C',
      '',
      '',
      '1',
      'facile',
      '',
      '',
      text,
      accepted.join('|'),
      answers.join('|'),
      bank.join('|'),
    ];
    return importer.parse(
      utf8.encode(
        [
          CsvImportService.recommendedHeader.join(';'),
          row.join(';'),
        ].join('\n'),
      ),
    );
  }

  StudyCard studyCard(CsvImportCardDraft draft) => StudyCard(
    id: 'card',
    collectionId: 'collection',
    deckId: 'deck',
    question: draft.question,
    correctAnswer: draft.correctAnswer,
    wrongAnswers: draft.wrongAnswers,
    hint: draft.hint,
    explanation: draft.explanation,
    currentTestMode: TestMode.cloze,
    allowedTestModes: draft.allowedTestModes,
    clozeText: draft.clozeText,
    clozeAnswers: draft.clozeAnswers,
    clozeWordBank: draft.clozeWordBank,
    acceptedAnswers: draft.acceptedAnswers,
    level: draft.level,
    progressDots: 0,
  );

  test('import, mode eligibility and every grader preserve answer meaning', () {
    for (final (answer, equivalent, different) in [
      ('ÉTÉ à Paris', '  été   À paris  ', 'ete a paris'),
      ('東京', ' 東京 ', '大阪'),
      ('ПРИВЕТ', 'привет', 'пока'),
      ('+', ' + ', '-'),
      ('C++', 'c++', 'C'),
      ('C#', 'c#', 'C++'),
      ('côte', 'CÔTE', 'cote'),
      // Canonical Unicode normalization is intentionally not provided.
      ('café', 'CAFÉ', 'cafe\u0301'),
    ]) {
      final preview = importCloze(
        text: 'Avant {{$answer}} après.',
        answers: [answer],
        bank: [equivalent, different],
      );
      expect(preview.issues, isEmpty, reason: answer);
      expect(preview.cards.single.allowedTestModes, contains(TestMode.cloze));
      final card = studyCard(preview.cards.single);
      expect(study.evaluateFreeText(card, equivalent), isTrue, reason: answer);
      expect(study.evaluateFreeText(card, different), isFalse, reason: answer);
      expect(study.evaluateFreeText(card, ''), isFalse, reason: answer);
      expect(study.evaluateMultipleChoice(card, 0, [equivalent]), isTrue);
      expect(study.evaluateMultipleChoice(card, 0, [different]), isFalse);
      expect(study.isTrueFalsePropositionCorrect(card, equivalent), isTrue);
      expect(study.isTrueFalsePropositionCorrect(card, different), isFalse);
      expect(study.evaluateCloze(card, [equivalent]), isTrue);
      expect(study.evaluateCloze(card, [different]), isFalse);
      expect(study.evaluateCloze(card, [null]), isFalse);
      expect(study.buildClozeSolution(card), 'Avant $answer après.');
      expect(study.buildClozeTokens(card).map((token) => token.gapIndex), [
        null,
        0,
        null,
      ]);
    }
  });

  test(
    'explicit accepted answers use the same whitespace and Unicode rule',
    () {
      final card = studyCard(
        importCloze(
          text: '{{東京}}',
          answers: ['東京'],
          bank: ['東京', '大阪'],
          accepted: ['東京', 'Tōkyō'],
        ).cards.single,
      );
      expect(study.evaluateFreeText(card, ' TŌKYŌ '), isTrue);
      expect(study.evaluateFreeText(card, 'Tokyo'), isFalse);
      expect(study.evaluateFreeText(card, '大阪'), isFalse);
    },
  );

  test('import and mode eligibility agree on cloze multiplicity and syntax', () {
    for (final (text, answers, bank, issue)
        in <(String, List<String>, List<String>, String?)>[
          (
            '{{été}} puis {{été}}',
            ['été', 'été'],
            ['ÉTÉ', ' été ', '東京'],
            null,
          ),
          (
            '{{été}} puis {{été}}',
            ['été', 'été'],
            ['ÉTÉ', '東京'],
            'cloze_word_bank doit contenir toutes les bonnes réponses. Manquantes : été.',
          ),
          (
            '{{été}}',
            ['été'],
            ['été', 'ÉTÉ'],
            'cloze_word_bank contient des doublons inutiles : ÉTÉ.',
          ),
          (
            '{{été}}',
            ['été'],
            ['été', '東京', '東京'],
            'cloze_word_bank contient des doublons inutiles : 東京.',
          ),
          (
            '{{東京}}',
            ['東京'],
            ['大阪'],
            'cloze_word_bank doit contenir toutes les bonnes réponses. Manquantes : 東京.',
          ),
          (
            '{} et {{}}',
            ['été'],
            ['été'],
            'cloze_text doit contenir au moins un trou au format {{réponse}}.',
          ),
          (
            '{{   }}',
            ['été'],
            ['été'],
            'cloze_text doit contenir au moins un trou au format {{réponse}}.',
          ),
          (
            '{{été}} puis {{東京}}',
            ['été'],
            ['été'],
            'Le nombre de cloze_answers doit correspondre exactement au nombre de trous dans cloze_text.',
          ),
        ]) {
      final preview = importCloze(text: text, answers: answers, bank: bank);
      final allowed = modes.allowedModesFor(
        clozeText: text,
        clozeAnswers: answers,
        clozeWordBank: bank,
        acceptedAnswers: const [],
      );
      expect(allowed.contains(TestMode.cloze), issue == null);
      if (issue != null) {
        expect(preview.cards, isEmpty);
        expect(preview.issues.single.message, issue);
      } else {
        expect(preview.issues, isEmpty);
        final card = studyCard(preview.cards.single);
        expect(study.evaluateCloze(card, ['ÉTÉ', ' été ']), isTrue);
        expect(study.evaluateCloze(card, ['été']), isFalse);
        expect(study.buildClozeSolution(card), 'été puis été');
        expect(
          study
              .buildClozeTokens(card)
              .where((token) => token.isGap)
              .map((token) => token.gapIndex),
          [0, 1],
        );
      }
    }
  });
}
