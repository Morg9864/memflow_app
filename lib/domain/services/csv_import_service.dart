import 'dart:convert';

import 'package:csv/csv.dart';

import '../models/models.dart';
import 'card_mode_service.dart';

class CsvImportService {
  CsvImportService(this._cardModeService);

  final CardModeService _cardModeService;

  static const recommendedHeader = [
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
    'cloze_answers',
    'cloze_word_bank',
  ];

  CsvImportPreview parse(List<int> bytes) {
    final raw = utf8
        .decode(bytes, allowMalformed: true)
        .replaceAll('\r\n', '\n');
    final delimiter = _detectDelimiter(raw);
    final rows = CsvDecoder(
      fieldDelimiter: delimiter,
      dynamicTyping: false,
    ).convert(raw);

    if (rows.isEmpty) {
      return const CsvImportPreview(
        cards: [],
        issues: [
          CsvImportIssue(rowNumber: 0, message: 'Le fichier CSV est vide.'),
        ],
        delimiter: ';',
        withHeader: true,
      );
    }

    final firstRow = rows.first.map((cell) => cell.toString().trim()).toList();
    final hasHeader = _looksLikeHeader(firstRow);
    final startIndex = hasHeader ? 1 : 0;
    final headerMap = hasHeader ? _buildHeaderMap(firstRow) : <String, int>{};
    final cards = <CsvImportCardDraft>[];
    final issues = <CsvImportIssue>[];

    for (var index = startIndex; index < rows.length; index++) {
      final row = rows[index].map((cell) => cell.toString().trim()).toList();
      if (row.every((cell) => cell.isEmpty)) {
        continue;
      }

      final rowNumber = index + 1;
      final collection = _readValue(row, 'collection', 0, headerMap);
      final deck = _readValue(row, 'deck', 1, headerMap);
      final question = _readValue(row, 'question', 2, headerMap);
      final correctAnswer = _readValue(row, 'correct_answer', 3, headerMap);
      final wrongAnswers = [
        _readValue(row, 'wrong_answer_1', 4, headerMap),
        _readValue(row, 'wrong_answer_2', 5, headerMap),
        _readValue(row, 'wrong_answer_3', 6, headerMap),
      ];

      if ([
        collection,
        deck,
        question,
        correctAnswer,
        ...wrongAnswers,
      ].any((value) => value.isEmpty)) {
        issues.add(
          CsvImportIssue(
            rowNumber: rowNumber,
            message:
                'Les colonnes collection, deck, question, correct_answer et les 3 mauvaises réponses sont obligatoires.',
          ),
        );
        continue;
      }

      final levelRaw = _readValue(row, 'level', 9, headerMap);
      final level = int.tryParse(levelRaw);
      if (level == null || level < 1 || level > 4) {
        issues.add(
          CsvImportIssue(
            rowNumber: rowNumber,
            message: 'Le niveau doit être un entier entre 1 et 4.',
          ),
        );
        continue;
      }

      final difficulty = _parseDifficulty(
        _readValue(row, 'difficulty', 10, headerMap),
      );
      if (difficulty == null) {
        issues.add(
          CsvImportIssue(
            rowNumber: rowNumber,
            message: 'La difficulté doit être facile, moyen ou avancé.',
          ),
        );
        continue;
      }

      final acceptedAnswers = _splitMultiValue(
        _readValue(row, 'accepted_answers', 14, headerMap),
      );
      final clozeAnswers = _splitMultiValue(
        _readValue(row, 'cloze_answers', 15, headerMap),
      );
      final clozeWordBank = _splitMultiValue(
        _readValue(row, 'cloze_word_bank', 16, headerMap),
      );
      final clozeText = _emptyToNull(
        _readValue(row, 'cloze_text', 13, headerMap),
      );
      final clozeIssue = _validateStructuredCloze(
        clozeText: clozeText,
        clozeAnswers: clozeAnswers,
        clozeWordBank: clozeWordBank,
      );
      if (clozeIssue != null) {
        issues.add(CsvImportIssue(rowNumber: rowNumber, message: clozeIssue));
        continue;
      }
      cards.add(
        CsvImportCardDraft(
          collection: collection,
          deck: deck,
          question: question,
          correctAnswer: correctAnswer,
          wrongAnswers: wrongAnswers,
          hint: _emptyToNull(_readValue(row, 'hint', 7, headerMap)),
          explanation: _emptyToNull(
            _readValue(row, 'explanation', 8, headerMap),
          ),
          level: level,
          difficulty: difficulty,
          tags: _splitMultiValue(_readValue(row, 'tags', 11, headerMap)),
          source: _emptyToNull(_readValue(row, 'source', 12, headerMap)),
          clozeText: clozeText,
          clozeAnswers: clozeAnswers,
          clozeWordBank: clozeWordBank,
          acceptedAnswers: acceptedAnswers,
          allowedTestModes: _cardModeService.allowedModesFor(
            clozeText: clozeText,
            clozeAnswers: clozeAnswers,
            clozeWordBank: clozeWordBank,
            acceptedAnswers: acceptedAnswers,
            wrongAnswers: wrongAnswers,
          ),
        ),
      );
    }

    return CsvImportPreview(
      cards: cards,
      issues: issues,
      delimiter: delimiter,
      withHeader: hasHeader,
    );
  }

  String _detectDelimiter(String raw) {
    final sample = raw.split('\n').take(5).join('\n');
    final delimiters = [';', ',', '\t'];
    return delimiters.reduce((best, candidate) {
      final bestCount = best == '\t'
          ? '\t'.allMatches(sample).length
          : best.allMatches(sample).length;
      final candidateCount = candidate == '\t'
          ? '\t'.allMatches(sample).length
          : candidate.allMatches(sample).length;
      return candidateCount > bestCount ? candidate : best;
    });
  }

  bool _looksLikeHeader(List<String> row) {
    final normalized = row.map((value) => value.toLowerCase()).toSet();
    return normalized.contains('collection') &&
        normalized.contains('correct_answer');
  }

  Map<String, int> _buildHeaderMap(List<String> row) {
    final map = <String, int>{};
    for (var index = 0; index < row.length; index++) {
      map[row[index].toLowerCase()] = index;
    }
    return map;
  }

  String _readValue(
    List<String> row,
    String key,
    int fallbackIndex,
    Map<String, int> headerMap,
  ) {
    final index = headerMap[key] ?? fallbackIndex;
    if (index < 0 || index >= row.length) {
      return '';
    }
    return row[index].trim();
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  List<String> _splitMultiValue(String value) {
    return value
        .split('|')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  String? _validateStructuredCloze({
    required String? clozeText,
    required List<String> clozeAnswers,
    required List<String> clozeWordBank,
  }) {
    final hasStructuredClozeData =
        clozeAnswers.isNotEmpty || clozeWordBank.isNotEmpty;
    if (!hasStructuredClozeData) {
      return null;
    }

    if (clozeText == null || clozeText.trim().isEmpty) {
      return 'Le mode texte à trous nécessite un cloze_text lorsque cloze_answers ou cloze_word_bank est renseigné.';
    }

    final placeholders = _extractClozePlaceholders(clozeText);
    if (placeholders.isEmpty) {
      return 'cloze_text doit contenir au moins un trou au format {{réponse}}.';
    }

    if (clozeAnswers.length != placeholders.length) {
      return 'Le nombre de cloze_answers doit correspondre exactement au nombre de trous dans cloze_text.';
    }

    if (clozeWordBank.isEmpty) {
      return 'cloze_word_bank est obligatoire pour activer un vrai texte à trous.';
    }

    final missingAnswers = _findMissingRequiredWords(
      haystack: clozeWordBank,
      needles: clozeAnswers,
    );
    if (missingAnswers.isNotEmpty) {
      return 'cloze_word_bank doit contenir toutes les bonnes réponses. Manquantes : ${missingAnswers.join(', ')}.';
    }

    final duplicatedWords = _findDuplicateWords(
      clozeWordBank,
      allowedDuplicates: _countByNormalized(clozeAnswers),
    );
    if (duplicatedWords.isNotEmpty) {
      return 'cloze_word_bank contient des doublons inutiles : ${duplicatedWords.join(', ')}.';
    }

    return null;
  }

  List<String> _extractClozePlaceholders(String text) {
    return RegExp(
      r'\{\{([^}]+)\}\}',
    ).allMatches(text).map((match) => match.group(1)!.trim()).toList();
  }

  List<String> _findMissingRequiredWords({
    required List<String> haystack,
    required List<String> needles,
  }) {
    final available = _countByNormalized(haystack);
    final missing = <String>[];

    for (final needle in needles) {
      final normalized = _normalize(needle);
      final count = available[normalized] ?? 0;
      if (count == 0) {
        missing.add(needle);
        continue;
      }
      available[normalized] = count - 1;
    }

    return missing;
  }

  List<String> _findDuplicateWords(
    List<String> words, {
    required Map<String, int> allowedDuplicates,
  }) {
    final seen = <String, int>{};
    final duplicates = <String>[];

    for (final word in words) {
      final normalized = _normalize(word);
      final nextCount = (seen[normalized] ?? 0) + 1;
      seen[normalized] = nextCount;
      final maxAllowed = allowedDuplicates[normalized] ?? 1;
      if (nextCount > maxAllowed && !duplicates.contains(word)) {
        duplicates.add(word);
      }
    }

    return duplicates;
  }

  Map<String, int> _countByNormalized(List<String> values) {
    final counts = <String, int>{};
    for (final value in values) {
      final normalized = _normalize(value);
      counts.update(normalized, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  DeckDifficulty? _parseDifficulty(String raw) {
    switch (raw.toLowerCase()) {
      case 'facile':
        return DeckDifficulty.facile;
      case 'moyen':
        return DeckDifficulty.moyen;
      case 'avance':
      case 'avancé':
        return DeckDifficulty.avance;
      case '':
        return DeckDifficulty.facile;
      default:
        return null;
    }
  }
}
