-- A disabled collection stays visible but its cards no longer participate in
-- study sessions or due-card totals. Deck states remain independent.
alter table public.collections
  add column if not exists is_disabled boolean not null default false;
