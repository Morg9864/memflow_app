begin;

-- A review can arrive long after it was taken on an offline device. Sync
-- cursors follow server receipt while statistics group by the original date.
alter table public.review_logs
  add column received_at timestamptz not null default now();
alter table public.review_logs
  alter column received_at set default clock_timestamp();
create index review_logs_owner_receipt_idx
  on public.review_logs (user_id, received_at, id);

-- Include ownership in the foreign keys so a plan can only point to a course
-- from the same account and, for deck plans, from the selected collection.
alter table public.collections
  add constraint collections_study_plan_owner_key unique (id, user_id);
alter table public.decks
  add constraint decks_study_plan_scope_key unique (id, collection_id, user_id);

create table public.study_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  collection_id text not null,
  deck_id text,
  start_date date not null check (start_date between date '0001-01-01' and date '9999-12-31'),
  weekdays integer[] not null default '{}'
    check (
      coalesce(array_ndims(weekdays), 1) = 1
      and cardinality(weekdays) <= 7
      and weekdays <@ array[1, 2, 3, 4, 5, 6, 7]
    ),
  follow_ups jsonb not null default '{}'::jsonb
    check (
      jsonb_typeof(follow_ups) = 'object'
      and (cardinality(weekdays) = 0 or follow_ups = '{}'::jsonb)
    ),
  deleted_at timestamptz,
  updated_at timestamptz not null default date_trunc('milliseconds', now()),
  foreign key (collection_id, user_id)
    references public.collections (id, user_id) on delete cascade,
  foreign key (deck_id, collection_id, user_id)
    references public.decks (id, collection_id, user_id) on delete cascade
);

create index study_plans_owner_scope_idx
  on public.study_plans (user_id, collection_id, deck_id);

create table public.study_preferences (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  srs_enabled boolean not null default false,
  updated_at timestamptz not null default date_trunc('milliseconds', now())
);

create function public.keep_newer_study_setting()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.updated_at < old.updated_at then
    return null;
  end if;
  if tg_table_name = 'study_plans' then
    if old.deleted_at is not null then
      return null;
    end if;
  end if;
  return new;
end;
$$;

revoke execute on function public.keep_newer_study_setting() from public, anon, authenticated;
create trigger keep_newer_study_plan
  before update on public.study_plans
  for each row execute function public.keep_newer_study_setting();
create trigger keep_newer_study_preference
  before update on public.study_preferences
  for each row execute function public.keep_newer_study_setting();

alter table public.study_plans enable row level security;
alter table public.study_preferences enable row level security;

revoke all on public.study_plans, public.study_preferences from public, anon, authenticated;
grant select, insert, update on public.study_plans, public.study_preferences to authenticated;
grant select, insert, update, delete on public.study_plans, public.study_preferences to service_role;

create policy "own study plans"
  on public.study_plans for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "own study preferences"
  on public.study_preferences for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime' and not puballtables) then
    alter publication supabase_realtime add table public.study_plans, public.study_preferences;
  end if;
end;
$$;

commit;
