#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

# Values from .env, when present, are compiled into the app. The database
# password is not needed to build, so it stays out of the build's environment.
if [ -f .env ]; then
  set -a
  . ./.env
  set +a
  unset SUPABASE_DB_PASSWORD
fi

# Without these the app builds, then stays stuck on its logo at launch.
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "build.sh: SUPABASE_URL and SUPABASE_ANON_KEY must be set (in .env or the environment)." >&2
  exit 1
fi

FLUTTER_VERSION="stable"
FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --no-analytics
flutter pub get

flutter build apk --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=SENTRY_DSN="$SENTRY_DSN"
