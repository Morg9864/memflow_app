-- Allow disabling a deck (e.g. once its exam is over) so the app stops taking
-- its cards into account for study sessions and due-card counts. The deck stays
-- visible (greyed out) and can be re-enabled at any time.
alter table public.decks
  add column if not exists is_disabled boolean not null default false;
