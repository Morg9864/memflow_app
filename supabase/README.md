# Supabase Setup

This project uses native Flutter environment loading with:

```bash
--dart-define-from-file=.env
```

## Apply the Database Schema

Use the migration in `supabase/migrations/20260529183000_init_memflow.sql`.

Options:

1. Supabase SQL Editor
2. Supabase CLI with `supabase db push`

## Current Security Model

The current app does not implement Supabase Auth yet.

Because of that, the migration enables RLS but adds open policies for `anon` and `authenticated` so the existing client can read and write data.

This is acceptable for development and internal testing only.

Before production:

1. Add authentication
2. Add a `user_id` ownership model
3. Replace the open policies with per-user policies
