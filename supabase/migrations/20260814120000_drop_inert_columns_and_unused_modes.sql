-- À APPLIQUER AVANT DE DÉPLOYER LE CLIENT QUI L'ACCOMPAGNE.
--
-- Le client n'écrit plus les colonnes d'agrégat supprimées ici. Tant que la
-- migration n'est pas passée, elles restent `not null` sans valeur par défaut
-- et tout insert du nouveau client échouerait.

begin;

-- 1. Colonnes d'agrégat jamais relues. Elles étaient écrites une seule fois à
-- l'import puis laissées telles quelles, pendant que l'application recalculait
-- systématiquement ces valeurs à partir des cartes. Une donnée fausse qui
-- traîne finit par être crue : on la supprime.
alter table public.collections
  drop column if exists total_cards,
  drop column if exists mastered_percentage;

alter table public.decks
  drop column if exists total_cards,
  drop column if exists due_cards,
  drop column if exists progress,
  drop column if exists status;

-- 2. Les modes `ordering` et `matching` n'ont jamais eu d'implémentation. Ils
-- sont retirés du domaine : on nettoie les données existantes avant de
-- resserrer les contraintes.
update public.flashcards
  set current_test_mode = 'multipleChoice'
  where current_test_mode in ('ordering', 'matching');

update public.flashcards
  set last_test_mode = null
  where last_test_mode in ('ordering', 'matching');

update public.flashcards
  set allowed_test_modes = array_remove(
    array_remove(allowed_test_modes, 'ordering'),
    'matching'
  )
  where allowed_test_modes && array['ordering', 'matching']::text[];

update public.flashcards
  set mode_history = array_remove(
    array_remove(mode_history, 'ordering'),
    'matching'
  )
  where mode_history && array['ordering', 'matching']::text[];

update public.review_logs
  set test_mode = 'multipleChoice'
  where test_mode in ('ordering', 'matching');

alter table public.flashcards
  drop constraint if exists flashcards_current_test_mode_check,
  drop constraint if exists flashcards_last_test_mode_check;

alter table public.flashcards
  add constraint flashcards_current_test_mode_check check (
    current_test_mode in (
      'multipleChoice',
      'classicFlashcard',
      'reversedFlashcard',
      'cloze',
      'freeText',
      'trueFalse'
    )
  ),
  add constraint flashcards_last_test_mode_check check (
    last_test_mode is null
    or last_test_mode in (
      'multipleChoice',
      'classicFlashcard',
      'reversedFlashcard',
      'cloze',
      'freeText',
      'trueFalse'
    )
  );

alter table public.review_logs
  drop constraint if exists review_logs_test_mode_check;

alter table public.review_logs
  add constraint review_logs_test_mode_check check (
    test_mode in (
      'multipleChoice',
      'classicFlashcard',
      'reversedFlashcard',
      'cloze',
      'freeText',
      'trueFalse'
    )
  );

-- 3. Le mode vrai/faux était implémenté mais n'était activé sur aucune carte :
-- il n'était ajouté aux modes autorisés que par un drapeau que l'import ne
-- passait jamais. Le choisir dans l'application retombait donc silencieusement
-- sur la flashcard classique. On l'active sur toutes les cartes qui portent au
-- moins une mauvaise réponse, seule condition pour pouvoir afficher une
-- affirmation fausse.
update public.flashcards
  set allowed_test_modes = array_append(allowed_test_modes, 'trueFalse')
  where not ('trueFalse' = any(allowed_test_modes))
    and exists (
      select 1
      from unnest(wrong_answers) as wrong_answer
      where btrim(wrong_answer) <> ''
    );

commit;
