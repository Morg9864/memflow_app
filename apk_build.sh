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

if ! command -v adb >/dev/null 2>&1; then
  echo "apk_build.sh: adb was not found. Install Android platform-tools and add adb to PATH." >&2
  exit 1
fi

DEVICE_SERIALS=$(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }')
DEVICE_COUNT=$(printf '%s\n' "$DEVICE_SERIALS" | awk 'NF { count++ } END { print count+0 }')

if [ "$DEVICE_COUNT" -eq 0 ]; then
  echo "apk_build.sh: no authorized Android device detected. Connect and authorize the tablet, then try again." >&2
  exit 1
fi

if [ "$DEVICE_COUNT" -gt 1 ]; then
  echo "apk_build.sh: multiple Android devices detected; connect only the tablet to install on." >&2
  printf '%s\n' "$DEVICE_SERIALS" >&2
  exit 1
fi

DEVICE_SERIAL=$DEVICE_SERIALS

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
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
adb -s "$DEVICE_SERIAL" install -r "$APK_PATH"
echo "Installed $APK_PATH on $DEVICE_SERIAL."
