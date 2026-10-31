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
| F0 | F | Visual harness and "before" screenshots | Done | 78 PNGs from 26 states in `build/visual/before`, 46 OK and 32 with overflow or failed interaction; harness skipped by default |
| A2 | A | Light-only, remove dark and Vivid | Done | 94 pass + 26 skipped, analyzer at baseline, overflow report unchanged |
| A3 | A | Tokens and theme | Done | 98 pass + 26 skipped, analyzer at baseline, palette and text-slot tests added |
| A4 | A | Shared widgets, move single-screen widgets | Done | 105 pass + 26 skipped, analyzer at baseline, overflow report unchanged, `ui.dart` 948 to 478 lines |
| D1 | D | Tab shell route | Done | 112 pass + 27 skipped, analyzer at baseline, shell tests including sign-out state reset |
| C1 | C | Study: layout | Done | 154 pass + 27 skipped, analyzer at baseline, all `study_*` captures OK, 13 protected functions byte-identical |
| C2 | C | Study: answers and feedback | Done | 222 pass + 27 skipped, analyzer at baseline, 17 study functions compared with baseline: only 3 haptic lines differ |
| C3 | C | Study: progress and ratings | Done | Pinned block 19% of 800px, analyzer at baseline, all `study_*` captures OK |
| C4 | C | Study: flashcards | In progress | |
| C5 | C | Mode sheet and session summary | Pending | |
| B1 | B | Home | Done (with B2) | 170 pass + 27 skipped, analyzer at baseline, all `home_*` captures OK |
| B2 | B | Collection card | Done (with B1) | 60-character titles shown in full at 320px and 2.0 text scale |
| B3 | B | Collection detail and lists | Done | Analyzer at baseline, `collection_detail__*` OK. Deck rows stay eager (two existing tests rely on it); title text scale capped at 1.4 to prevent mid-word breaks |
| E1 | E | Statistics | Done | 190 pass + 27 skipped, analyzer at baseline, all `stats_*` captures OK, full-length view reviewed |
| E2 | E | CSV import | Done | 235 pass + 28 skipped, analyzer at baseline, preview state added to harness and reviewed, import failure wording checked against the transaction |
| E3 | E | Profile and settings | In progress | |
| E4 | E | Auth, legal, not found | In progress | |
| D2 | D | Motion and performance pass | Pending | |
| F1 | F | Accessibility and regression tests | Pending | |
| F2 | F | Profile-mode measurements | Blocked: needs a device | |

## Audit corrections
- Audit defect 3 was partly wrong. `Theme.of` merges a default text geometry, so `titleSmall` and `labelSmall` are not null and colours do apply. The real defect is that those slots have no font family, so they use the platform font instead of Outfit. Text in those slots with no explicit colour also rendered white in the harness (for example the profile sync title), so it may be invisible on devices too. The A3 fix (define every slot) is unchanged.
- Audit defect 4 was incomplete. `filledButtonTheme` sets `backgroundColor`, which also overrides the tonal variant, so the theme must stop setting it as well as changing `secondaryContainer`.

## Before-state evidence (`build/visual/before/report.txt`)
- Session summary overflows at every viewport: 230px, 621px and 1263px.
- Home overflows horizontally at default text scale: 79px on phone and 99px on small.
- At 320x568, true/false and cloze controls can't be reached.
- At 2.0 text scale, every study mode overflows 84px on the right.

## Test changes to existing files
- `collection_detail_screen_test.dart`: the `_selectDeckSort` helper now scrolls the sort button into view before tapping. The correctly sized "Voir les échéances" button pushed it off the 800x600 test surface. The sort assertions are unchanged.

## Review notes for later tasks
- C3: the pinned rating block covers about 40% of an 800px phone, which hides feedback until scrolling. It must shrink.
- C4: on long flashcards nothing shows that more text exists below the pinned button.

## Decisions needed from the product owner
- Study header progress dots: `progressDots` is a per-card count (3 to 6, from repetitions), but dots light up by session position, so they carry no real information. Options: remove them, or show repetitions against a fixed target. Left unchanged for now.

## Known issues and blockers
- Riverpod 3 retries failed stream providers by default, so error states may appear after a delay, with skeletons in the meantime. No app-wide `retry` config was added. To verify on a device.
- F2 needs a physical device or emulator. None available at the start.
- Out of scope, to report and not fix:
  - "Revoir mes erreurs" shows the mode sheet but ignores the choice.
  - `/study/errors` and `/session-summary` crash on direct links (null `extra`).
  - The email-change success message names the current address, while the dialog says the new one.
  - `sqlite3` is imported without being a direct dependency.
  - `md/instructions.md` still describes dark and light themes. Left as the historical original brief.

## Remaining work
All tasks above not marked done.
