begin;

-- Per-user ownership. `default auth.uid()` fills the column automatically for
-- inserts made by an authenticated client; the sync client also sets it
-- explicitly. The column stays nullable so this migration does not fail on any
-- legacy rows created under the previous open-access model (those rows are
-- hidden by the per-user policies below and can be purged manually).
alter table public.collections
  add column if not exists user_id uuid references auth.users(id) on delete cascade default auth.uid();
alter table public.decks
  add column if not exists user_id uuid references auth.users(id) on delete cascade default auth.uid();
alter table public.flashcards
  add column if not exists user_id uuid references auth.users(id) on delete cascade default auth.uid();
alter table public.review_logs
  add column if not exists user_id uuid references auth.users(id) on delete cascade default auth.uid();

create index if not exists collections_user_id_idx on public.collections (user_id);
create index if not exists decks_user_id_idx on public.decks (user_id);
create index if not exists flashcards_user_id_idx on public.flashcards (user_id);
create index if not exists review_logs_user_id_idx on public.review_logs (user_id);

-- Drop the development-only open-access policies.
drop policy if exists "open access collections" on public.collections;
drop policy if exists "open access decks" on public.decks;
drop policy if exists "open access flashcards" on public.flashcards;
drop policy if exists "open access review_logs" on public.review_logs;

-- Restrict access to the owning authenticated user only.
create policy "own collections"
  on public.collections
  for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "own decks"
  on public.decks
  for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "own flashcards"
  on public.flashcards
  for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "own review_logs"
  on public.review_logs
  for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- The anonymous role no longer has direct table access.
revoke select, insert, update, delete on all tables in schema public from anon;

commit;
