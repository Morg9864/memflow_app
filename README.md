# MemFlow

MemFlow is a premium offline-first Flutter flashcards app for web and mobile.

The application focuses on spaced repetition, collection/deck management, CSV import/export, local-first persistence, and optional cloud synchronization.

## Core Features

- Offline-first study workflow with local persistence.
- Spaced repetition scheduling logic.
- Multiple test modes (QCM, classic/reversed flashcard, cloze, free text, etc.).
- Collection and deck organization.
- Study session summary and statistics.
- CSV import/export services.
- Optional Supabase sync (enabled only when env vars are provided).
- Light and dark themes.

## Tech Stack

- Flutter + Dart
- Riverpod (state management / DI)
- go_router (navigation)
- Drift + SQLite (local database)
- Supabase (cloud sync layer)
- shared_preferences (small local settings)

## Project Structure

The app follows a clean, feature-first architecture:

```
lib/
	app/            # bootstrap, app root, router, providers
	data/           # local DB and repository implementations
	domain/         # models and business services
	features/       # UI screens by feature (home, study, stats, import...)
	theme/          # light/dark theme and controller
	widgets/        # reusable UI widgets
	utils/          # utility helpers
```

## Requirements

- Flutter SDK (stable)
- Dart SDK (included with Flutter)
- Android Studio / Xcode (for mobile targets)
- A modern browser (for web)

Check your setup:

```bash
flutter doctor
```

## Installation

```bash
flutter pub get
```

## Run the App

### Web

```bash
flutter run -d chrome --dart-define-from-file=.env
```

### Android/iOS

```bash
flutter run --dart-define-from-file=.env
```

## Supabase Configuration (Optional)

Cloud sync is optional. If variables are not provided, the app still runs locally.

The app expects compile-time variables loaded natively by Flutter from `.env`:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

1. Copy `.env.example` to `.env`
2. Fill in the values from your Supabase project
3. Run or build with `--dart-define-from-file=.env`

Example:

```bash
flutter run -d chrome --dart-define-from-file=.env
```

The app reads these values with `String.fromEnvironment(...)` during bootstrap.

The Supabase database schema is versioned in:

```bash
supabase/migrations/20260529183000_init_memflow.sql
```

Apply it in the Supabase SQL Editor or with the Supabase CLI before using cloud sync.

## Drift Code Generation

If you change Drift schema or DAOs, regenerate files with:

```bash
dart run build_runner build --delete-conflicting-outputs
```

For watch mode:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Tests

Run all tests:

```bash
flutter test
```

Targeted service tests:

```bash
flutter test test/services/spaced_repetition_service_test.dart
flutter test test/services/card_mode_service_test.dart
flutter test test/services/sync_service_test.dart
```

## Build

### Web

```bash
flutter build web --dart-define-from-file=.env
```

### Android

```bash
flutter build apk --dart-define-from-file=.env
```

### iOS

```bash
flutter build ios --dart-define-from-file=.env
```

## Notes on Offline-First Behavior

- Local database is the source of truth for reads.
- Cloud sync is best-effort and optional.
- Without Supabase variables, synchronization is disabled and local usage remains fully functional.

## Useful Commands

```bash
flutter analyze
flutter test
flutter clean
flutter pub get
```

## License

Private project. Add a license file if you plan to open-source it.
