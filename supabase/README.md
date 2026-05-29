# Supabase Setup

This project uses native Flutter environment loading with:

```bash
--dart-define-from-file=.env
```

## Apply the Database Schema

Apply the migrations in order:

1. `supabase/migrations/20260529183000_init_memflow.sql` — base tables.
2. `supabase/migrations/20260529190000_add_user_scoping.sql` — per-user ownership + RLS.

Options:

1. Supabase SQL Editor
2. Supabase CLI with `supabase db push`

## Security Model

The app uses Supabase Auth with email + password.

Each table has a `user_id` column (defaulting to `auth.uid()`) and per-user RLS
policies (`auth.uid() = user_id`) for the `authenticated` role only. The `anon`
role has no direct table access. The sync client stamps `user_id` on every push
and filters pulls by the current user.

### Auth configuration (dashboard)

Configure email confirmation for password sign-up as desired
(**Authentication → Providers → Email**). Email is enabled by default.

### Legacy data

Rows created under the previous open-access model have a `null` `user_id` and are
hidden by the new policies. Purge them with
`delete from public.collections where user_id is null;` (and the other tables) if
needed.
