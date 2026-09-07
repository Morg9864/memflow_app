/// Answer matching ignores case and whitespace only. Accents, other scripts,
/// punctuation and symbols carry meaning (for example C, C# and C++).
///
/// This uses Dart's lowercase mapping, not locale-specific case folding or
/// Unicode canonical normalization: composed and decomposed accents remain
/// distinct. Import and study deliberately use this same rule.
String normalizeAnswer(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'\s+', unicode: true), ' ').trim();

/// The same placeholder syntax drives validation, rendering and solutions.
final clozePlaceholderPattern = RegExp(r'\{\{([^{}]*\S[^{}]*)\}\}');

enum ClozeIssue {
  missingText,
  missingPlaceholders,
  answerCountMismatch,
  missingWordBank,
  missingAnswers,
  duplicateWords,
}

class ClozeValidationIssue {
  const ClozeValidationIssue(this.reason, [this.words = const []]);

  final ClozeIssue reason;
  final List<String> words;
}

/// Each gap consumes one matching word from the bank. Repeated answers need
/// repeated bank entries; distractors may appear only once.
ClozeValidationIssue? validateStructuredCloze({
  required String? clozeText,
  required List<String> clozeAnswers,
  required List<String> clozeWordBank,
}) {
  if (clozeText == null || clozeText.trim().isEmpty) {
    return const ClozeValidationIssue(ClozeIssue.missingText);
  }
  final holeCount = clozePlaceholderPattern.allMatches(clozeText).length;
  if (holeCount == 0) {
    return const ClozeValidationIssue(ClozeIssue.missingPlaceholders);
  }
  if (holeCount != clozeAnswers.length) {
    return const ClozeValidationIssue(ClozeIssue.answerCountMismatch);
  }
  if (clozeWordBank.isEmpty) {
    return const ClozeValidationIssue(ClozeIssue.missingWordBank);
  }

  final available = _answerCounts(clozeWordBank);
  final missing = <String>[];
  for (final answer in clozeAnswers) {
    final key = normalizeAnswer(answer);
    final count = available[key] ?? 0;
    if (count == 0) {
      missing.add(answer);
    } else {
      available[key] = count - 1;
    }
  }
  if (missing.isNotEmpty) {
    return ClozeValidationIssue(ClozeIssue.missingAnswers, missing);
  }

  final requiredCounts = _answerCounts(clozeAnswers);
  final seen = <String, int>{};
  final duplicates = <String>[];
  for (final word in clozeWordBank) {
    final key = normalizeAnswer(word);
    final count = (seen[key] ?? 0) + 1;
    seen[key] = count;
    if (count > (requiredCounts[key] ?? 1) && !duplicates.contains(word)) {
      duplicates.add(word);
    }
  }
  return duplicates.isEmpty
      ? null
      : ClozeValidationIssue(ClozeIssue.duplicateWords, duplicates);
}

Map<String, int> _answerCounts(List<String> values) {
  final counts = <String, int>{};
  for (final value in values) {
    counts.update(
      normalizeAnswer(value),
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }
  return counts;
}
