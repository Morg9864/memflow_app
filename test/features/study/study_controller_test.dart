import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/features/study/study_controller.dart';

void main() {
  StudyCard buildCard(String id) {
    return StudyCard(
      id: id,
      collectionId: 'react',
      deckId: 'deck-1',
      question: 'Question $id',
      correctAnswer: 'Réponse $id',
      wrongAnswers: const ['A', 'B', 'C'],
      hint: null,
      explanation: null,
      currentTestMode: TestMode.multipleChoice,
      allowedTestModes: const [
        TestMode.multipleChoice,
        TestMode.classicFlashcard,
      ],
      clozeText: null,
      clozeAnswers: const [],
      clozeWordBank: const [],
      acceptedAnswers: const [],
      level: 1,
      progressDots: 3,
    );
  }

  StudyCard buildTrueFalseCard({
    String id = 'tf',
    String correctAnswer = 'Paris',
    List<String> wrongAnswers = const ['Lyon', 'Marseille', 'Bordeaux'],
  }) {
    return StudyCard(
      id: id,
      collectionId: 'geo',
      deckId: 'deck-1',
      question: 'Quelle est la capitale de la France ?',
      correctAnswer: correctAnswer,
      wrongAnswers: wrongAnswers,
      hint: null,
      explanation: null,
      currentTestMode: TestMode.trueFalse,
      allowedTestModes: const [TestMode.trueFalse],
      clozeText: null,
      clozeAnswers: const [],
      clozeWordBank: const [],
      acceptedAnswers: const [],
      level: 1,
      progressDots: 3,
    );
  }

  StudyCard buildClozeCard() {
    return StudyCard(
      id: 'cloze',
      collectionId: 'react',
      deckId: 'deck-1',
      question: 'Quel hook React gère un état local ?',
      correctAnswer: 'useState',
      wrongAnswers: const ['useEffect', 'useMemo', 'useRef'],
      hint: null,
      explanation: null,
      currentTestMode: TestMode.cloze,
      allowedTestModes: const [TestMode.cloze],
      clozeText:
          'React, le hook {{useState}} retourne une valeur actuelle et une fonction pour la {{modifier}}.',
      clozeAnswers: const ['useState', 'modifier'],
      clozeWordBank: const ['useState', 'useEffect', 'afficher', 'modifier'],
      acceptedAnswers: const [],
      level: 1,
      progressDots: 3,
    );
  }

  StudySessionState buildState(List<StudyCard> cards) {
    return StudySessionState(
      deckTitle: 'React',
      collectionId: 'react',
      deckId: 'deck-1',
      cards: cards,
      currentIndex: 0,
      revealed: false,
      selectedOptionIndex: null,
      hasValidatedAnswer: false,
      freeTextAnswer: '',
      reviewCounts: const {
        ReviewResult.again: 0,
        ReviewResult.hard: 0,
        ReviewResult.good: 0,
        ReviewResult.easy: 0,
      },
      currentAnswerWasCorrect: null,
      isCompleted: false,
    );
  }

  test('la session garde un ordre fixe et ne rejoue aucune carte', () {
    final controller = StudyRules(random: math.Random(0));
    final initialState = buildState([
      buildCard('a'),
      buildCard('b'),
      buildCard('c'),
    ]);

    final nextState = controller.advance(initialState, ReviewResult.hard);

    expect(nextState.currentCard.id, 'b');
    expect(nextState.cards.map((card) => card.id).toList(), ['a', 'b', 'c']);
  });

  test('une carte ratée ne rallonge pas la session courante', () {
    final controller = StudyRules(random: math.Random(0));
    final initialState = buildState([
      buildCard('a'),
      buildCard('b'),
      buildCard('c'),
    ]);

    final afterA = controller.advance(initialState, ReviewResult.again);
    final afterB = controller.advance(afterA, ReviewResult.again);
    final afterC = controller.advance(afterB, ReviewResult.again);

    expect(afterA.cards.map((card) => card.id).toList(), ['a', 'b', 'c']);
    expect(afterA.currentCard.id, 'b');
    expect(afterB.currentCard.id, 'c');
    expect(afterC.isCompleted, isTrue);
    expect(afterC.cards, hasLength(3));
    expect(afterC.reviewCounts[ReviewResult.again], 3);
  });

  group('mode vrai/faux', () {
    final controller = StudyRules(random: math.Random(0));

    test('la proposition est toujours tirée du jeu de réponses du CSV', () {
      final card = buildTrueFalseCard();
      final pool = {card.correctAnswer, ...card.wrongAnswers};
      for (var i = 0; i < 50; i++) {
        final proposition = controller.buildTrueFalseProposition(card);
        expect(proposition, isNotNull);
        expect(pool.contains(proposition), isTrue);
      }
    });

    test(
      '"Vrai" est correct quand la proposition affichée est la bonne réponse',
      () {
        final card = buildTrueFalseCard();
        expect(controller.isTrueFalsePropositionCorrect(card, 'Paris'), isTrue);
        expect(
          controller.evaluateTrueFalse(card, 'Paris', answeredTrue: true),
          isTrue,
        );
        expect(
          controller.evaluateTrueFalse(card, 'Paris', answeredTrue: false),
          isFalse,
        );
      },
    );

    test(
      '"Faux" est correct quand la proposition affichée est une mauvaise réponse',
      () {
        final card = buildTrueFalseCard();
        expect(controller.isTrueFalsePropositionCorrect(card, 'Lyon'), isFalse);
        expect(
          controller.evaluateTrueFalse(card, 'Lyon', answeredTrue: false),
          isTrue,
        );
        expect(
          controller.evaluateTrueFalse(card, 'Lyon', answeredTrue: true),
          isFalse,
        );
      },
    );

    test(
      'la correction ne dépend pas des mots "vrai"/"faux"/"true"/"false"',
      () {
        // Aucune des réponses ne contient ces mots : l'ancienne heuristique
        // aurait systématiquement classé la carte comme "Faux".
        final card = buildTrueFalseCard();
        expect(
          controller.evaluateTrueFalse(card, 'Paris', answeredTrue: true),
          isTrue,
        );
      },
    );

    test('prepareCurrentCard mémorise une proposition stable', () {
      final state = buildState([buildTrueFalseCard()]);
      final prepared = controller.prepareCurrentCard(state);
      final pool = {
        prepared.currentCard.correctAnswer,
        ...prepared.currentCard.wrongAnswers,
      };
      expect(prepared.trueFalseProposition, isNotNull);
      expect(pool.contains(prepared.trueFalseProposition), isTrue);
    });

    test('aucune proposition pour un mode autre que vrai/faux', () {
      final card = buildCard('a'); // multipleChoice
      expect(controller.buildTrueFalseProposition(card), isNull);
      final prepared = controller.prepareCurrentCard(buildState([card]));
      expect(prepared.trueFalseProposition, isNull);
    });

    test('les mauvaises réponses vides ne sont jamais proposées', () {
      // Certaines lignes du CSV laissent des colonnes wrong_answer_* vides.
      final card = buildTrueFalseCard(wrongAnswers: const ['Lyon', '', '   ']);
      for (var i = 0; i < 50; i++) {
        final proposition = controller.buildTrueFalseProposition(card);
        expect(proposition, isNotNull);
        expect(proposition!.trim().isNotEmpty, isTrue);
        expect({'Paris', 'Lyon'}.contains(proposition), isTrue);
      }
    });
  });

  group('mode texte à trous', () {
    final controller = StudyRules(random: math.Random(0));

    test('construit des tokens inline pour les trous', () {
      final tokens = controller.buildClozeTokens(buildClozeCard());

      expect(tokens.where((token) => token.isGap).length, 2);
      expect(
        tokens.where((token) => !token.isGap).map((token) => token.text).join(),
        contains('React, le hook '),
      );
    });

    test('valide chaque trou dans l’ordre attendu', () {
      final card = buildClozeCard();

      expect(
        controller.evaluateCloze(card, const ['useState', 'modifier']),
        isTrue,
      );
      expect(
        controller.evaluateCloze(card, const ['modifier', 'useState']),
        isFalse,
      );
      expect(
        controller.evaluateClozeGaps(card, const ['useState', 'afficher']),
        [true, false],
      );
    });

    test('reconstruit le texte complet pour le feedback', () {
      final solution = controller.buildClozeSolution(buildClozeCard());

      expect(
        solution,
        'React, le hook useState retourne une valeur actuelle et une fonction pour la modifier.',
      );
    });
  });
}
