begin;

alter table public.decks
  drop constraint if exists decks_difficulty_check;

alter table public.decks
  add constraint decks_difficulty_check check (
    difficulty in ('facile', 'moyen', 'difficile', 'avance')
  );

alter table public.flashcards
  drop constraint if exists flashcards_difficulty_check;

alter table public.flashcards
  add constraint flashcards_difficulty_check check (
    difficulty is null
    or difficulty in ('facile', 'moyen', 'difficile', 'avance')
  );

commit;
