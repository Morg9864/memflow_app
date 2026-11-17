begin;

-- The remote schema snapshot restored broad default grants to anon and
-- authenticated. Keep existing explicit table grants, but make future public
-- objects inaccessible until they are reviewed and granted deliberately.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres
  revoke execute on routines from public;
alter default privileges for role postgres in schema public
  revoke execute on routines from anon, authenticated;

revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke execute on all routines in schema public from public, anon, authenticated;

-- Keep RLS on every table already present in the exposed public schema.
do $$
declare
  table_name text;
begin
  for table_name in
    select tablename from pg_tables where schemaname = 'public'
  loop
    execute format('alter table public.%I enable row level security', table_name);
  end loop;
end;
$$;

commit;
