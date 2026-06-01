begin;

alter table public.flashcards
  add column if not exists cloze_answers text[] not null default '{}'::text[],
  add column if not exists cloze_word_bank text[] not null default '{}'::text[];

commit;
