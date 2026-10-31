# Memflow redesign: progress tracker

Source of truth: `refonte.md`. Baseline: tag `refonte-baseline` (`55ade2e`). Work branch: `refonte/ui` (local only).

Coordinator and reviewer: Opus 5.5 (`claude-opus-5-5`). Implementers: Sonnet 5.5 (`claude-sonnet-5-5`, verified).

## Decisions
- Green, red and blue keep their exact values, only for answer results and rating buttons, always with icon and text. Red also stays for errors and destructive actions. All other UI and all charts use orange and neutrals.
- Main 56px buttons: white label, 19px bold (3.05:1, AA large). Small actions: tonal `FCE9DC` with dark text (15:1).

## Baseline validation
- `flutter test`: 94/94 pass.
- `flutter analyze`: 4 infos, no errors or warnings.
- Profile-mode measurements: not run, no device or emulator connected.

## Tasks

Dependencies: A1 → F0 → A2 → A3 → A4 → D1 → (C1–C5, B1–B3, E1–E4 in parallel) → D2 → F1 → F2 → final review.

| Task | Agent | Scope | Status | Validation |
|---|---|---|---|---|
| A1 | A | Bundle fonts, stop bundling `design/`, logo `cacheWidth` | Done | 95/95 tests, analyzer at baseline, font checksums verified, `design/` out of bundle |
| F0 | F | Visual harness and "before" screenshots | In progress | |
| A2 | A | Light-only, remove dark and Vivid | Pending | |
| A3 | A | Tokens and theme | Pending | |
| A4 | A | Shared widgets, move single-screen widgets | Pending | |
| D1 | D | Tab shell route | Pending | |
| C1 | C | Study: layout | Pending | |
| C2 | C | Study: answers and feedback | Pending | |
| C3 | C | Study: progress and ratings | Pending | |
| C4 | C | Study: flashcards | Pending | |
| C5 | C | Mode sheet and session summary | Pending | |
| B1 | B | Home | Pending | |
| B2 | B | Collection card | Pending | |
| B3 | B | Collection detail and lists | Pending | |
| E1 | E | Statistics | Pending | |
| E2 | E | CSV import | Pending | |
| E3 | E | Profile and settings | Pending | |
| E4 | E | Auth, legal, not found | Pending | |
| D2 | D | Motion and performance pass | Pending | |
| F1 | F | Accessibility and regression tests | Pending | |
| F2 | F | Profile-mode measurements | Blocked: needs a device | |

## Known issues and blockers
- F2 needs a physical device or emulator. None available at the start.
- Out of scope, to report and not fix:
  - "Revoir mes erreurs" shows the mode sheet but ignores the choice.
  - `/study/errors` and `/session-summary` crash on direct links (null `extra`).
  - The email-change success message names the current address, while the dialog says the new one.
  - `sqlite3` is imported without being a direct dependency.

## Remaining work
All tasks above not marked done.
