begin;

create table if not exists public.collections (
  id text primary key,
  name text not null,
  description text not null,
  icon text not null,
  total_cards integer not null check (total_cards >= 0),
  mastered_percentage double precision not null check (
    mastered_percentage >= 0
    and mastered_percentage <= 1
  ),
  color integer not null,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table if not exists public.decks (
  id text primary key,
  collection_id text not null references public.collections(id) on delete cascade,
  name text not null,
  icon text not null,
  difficulty text not null check (difficulty in ('facile', 'moyen', 'avance')),
  total_cards integer not null check (total_cards >= 0),
  due_cards integer not null check (due_cards >= 0),
  progress double precision not null check (progress >= 0 and progress <= 1),
  status text not null check (status in ('nouveau', 'maitrise', 'dues')),
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table if not exists public.flashcards (
  id text primary key,
  collection_id text not null references public.collections(id) on delete cascade,
  deck_id text not null references public.decks(id) on delete cascade,
  question text not null,
  correct_answer text not null,
  answer text,
  wrong_answers text[] not null default '{}'::text[],
  hint text,
  explanation text,
  current_test_mode text not null check (
    current_test_mode in (
      'multipleChoice',
      'classicFlashcard',
      'reversedFlashcard',
      'cloze',
      'freeText',
      'trueFalse',
      'ordering',
      'matching'
    )
  ),
  allowed_test_modes text[] not null default '{}'::text[],
  last_test_mode text check (
    last_test_mode is null
    or last_test_mode in (
      'multipleChoice',
      'classicFlashcard',
      'reversedFlashcard',
      'cloze',
      'freeText',
      'trueFalse',
      'ordering',
      'matching'
    )
  ),
  mode_history text[] not null default '{}'::text[],
  cloze_text text,
  accepted_answers text[] not null default '{}'::text[],
  source text,
  difficulty text check (difficulty is null or difficulty in ('facile', 'moyen', 'avance')),
  level integer not null check (level >= 1),
  tags text[] not null default '{}'::text[],
  due_at timestamptz not null,
  last_reviewed_at timestamptz,
  interval_days double precision not null,
  ease_factor double precision not null,
  repetitions integer not null check (repetitions >= 0),
  lapses integer not null check (lapses >= 0),
  mastered boolean not null,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table if not exists public.review_logs (
  id text primary key,
  flashcard_id text not null references public.flashcards(id) on delete cascade,
  collection_id text not null references public.collections(id) on delete cascade,
  deck_id text not null references public.decks(id) on delete cascade,
  review_result text not null check (review_result in ('again', 'hard', 'good', 'easy')),
  test_mode text not null check (
    test_mode in (
      'multipleChoice',
      'classicFlashcard',
      'reversedFlashcard',
      'cloze',
      'freeText',
      'trueFalse',
      'ordering',
      'matching'
    )
  ),
  was_correct boolean not null,
  created_at timestamptz not null,
  scheduled_due_at timestamptz not null
);

create index if not exists collections_updated_at_idx
  on public.collections (updated_at);

create index if not exists decks_collection_id_idx
  on public.decks (collection_id);

create index if not exists decks_updated_at_idx
  on public.decks (updated_at);

create index if not exists flashcards_collection_id_idx
  on public.flashcards (collection_id);

create index if not exists flashcards_deck_id_idx
  on public.flashcards (deck_id);

create index if not exists flashcards_due_at_idx
  on public.flashcards (due_at);

create index if not exists flashcards_updated_at_idx
  on public.flashcards (updated_at);

create index if not exists review_logs_flashcard_id_idx
  on public.review_logs (flashcard_id);

create index if not exists review_logs_collection_id_idx
  on public.review_logs (collection_id);

create index if not exists review_logs_deck_id_idx
  on public.review_logs (deck_id);

create index if not exists review_logs_created_at_idx
  on public.review_logs (created_at);

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to anon, authenticated;

alter table public.collections enable row level security;
alter table public.decks enable row level security;
alter table public.flashcards enable row level security;
alter table public.review_logs enable row level security;

create policy "open access collections"
  on public.collections
  for all
  to anon, authenticated
  using (true)
  with check (true);

create policy "open access decks"
  on public.decks
  for all
  to anon, authenticated
  using (true)
  with check (true);

create policy "open access flashcards"
  on public.flashcards
  for all
  to anon, authenticated
  using (true)
  with check (true);

create policy "open access review_logs"
  on public.review_logs
  for all
  to anon, authenticated
  using (true)
  with check (true);

commit;
