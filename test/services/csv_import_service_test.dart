import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/domain/services/card_mode_service.dart';
import 'package:memflow/domain/services/csv_import_service.dart';

void main() {
  final service = CsvImportService(const CardModeService());

  test('empty backup is rejected before decoding', () {
    final preview = service.parse(const []);

    expect(preview.cards, isEmpty);
    expect(preview.issues, hasLength(1));
    expect(preview.issues.single.message, 'Le fichier CSV est vide.');
  });

  test('legacy CSV rows keep free text but no longer activate cloze', () {
    final csv = [
      'collection;deck;question;correct_answer;wrong_answer_1;wrong_answer_2;wrong_answer_3;hint;explanation;level;tags;source;cloze_text;accepted_answers',
      'React;Hooks;Quel hook garde un état local ?;useState;useEffect;useMemo;useRef;-;useState crée un état local.;1;react|hooks;Cours React;React utilise {{useState}}.;useState|use state',
    ].join('\n');

    final preview = service.parse(utf8.encode(csv));

    expect(preview.issues, isEmpty);
    expect(preview.cards, hasLength(1));
    expect(preview.cards.single.allowedTestModes, contains(TestMode.freeText));
    expect(
      preview.cards.single.allowedTestModes,
      isNot(contains(TestMode.cloze)),
    );
  });

  test('structured cloze rows activate true cloze mode', () {
    final csv = [
      'collection;deck;question;correct_answer;wrong_answer_1;wrong_answer_2;wrong_answer_3;hint;explanation;level;tags;source;cloze_text;accepted_answers;cloze_answers;cloze_word_bank',
      'React;Hooks;Quel hook garde un état local ?;useState;useEffect;useMemo;useRef;-;useState crée un état local.;1;react|hooks;Cours React;Le hook {{useState}} retourne une valeur et une fonction pour la {{modifier}}.;useState|use state;useState|modifier;useState|useEffect|modifier|afficher',
    ].join('\n');

    final preview = service.parse(utf8.encode(csv));

    expect(preview.issues, isEmpty);
    expect(preview.cards, hasLength(1));
    expect(preview.cards.single.clozeAnswers, ['useState', 'modifier']);
    expect(preview.cards.single.clozeWordBank, [
      'useState',
      'useEffect',
      'modifier',
      'afficher',
    ]);
    expect(preview.cards.single.allowedTestModes, contains(TestMode.cloze));
  });

  test('invalid structured cloze rows are rejected with a clear issue', () {
    final csv = [
      'collection;deck;question;correct_answer;wrong_answer_1;wrong_answer_2;wrong_answer_3;hint;explanation;level;tags;source;cloze_text;accepted_answers;cloze_answers;cloze_word_bank',
      'React;Hooks;Quel hook garde un état local ?;useState;useEffect;useMemo;useRef;-;useState crée un état local.;1;react|hooks;Cours React;Le hook {{useState}} retourne une valeur et une fonction pour la {{modifier}}.;useState|use state;useState;useState|useEffect|modifier|afficher',
    ].join('\n');

    final preview = service.parse(utf8.encode(csv));

    expect(preview.cards, isEmpty);
    expect(preview.issues, hasLength(1));
    expect(
      preview.issues.single.message,
      contains('Le nombre de cloze_answers'),
    );
  });
}
