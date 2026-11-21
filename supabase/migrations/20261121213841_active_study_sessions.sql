begin;

create table public.active_study_sessions (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  session_data jsonb not null check (jsonb_typeof(session_data) = 'object'),
  updated_at timestamptz not null default date_trunc('milliseconds', now())
);

create function public.keep_newer_active_study_session()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.updated_at < old.updated_at then
    return null;
  end if;
  return new;
end;
$$;

revoke execute on function public.keep_newer_active_study_session() from public, anon, authenticated;
create trigger keep_newer_active_study_session
  before update on public.active_study_sessions
  for each row execute function public.keep_newer_active_study_session();

alter table public.active_study_sessions enable row level security;
revoke all on public.active_study_sessions from public, anon, authenticated;
grant select, insert, update on public.active_study_sessions to authenticated;
grant select, insert, update, delete on public.active_study_sessions to service_role;

create policy "own active study session"
  on public.active_study_sessions for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

commit;
