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
| C4 | C | Study: flashcards | Done | 377 pass + 28 skipped, analyzer at baseline, `study_flash*` captures OK and reviewed. Review fixed one defect: the scroll fade reacted to nested scrollables (regression test confirmed failing without the fix) |
| C5 | C | Mode sheet and session summary | Done | 405 pass + 28 skipped, analyzer at baseline, all `session_summary__*` and `mode_sheet__*` captures OK, phone and small reviewed. Review fixed a blank dead-end screen when the availability check fails (test fails without the fix). Commit `e4d664d` doesn't compile because of a missing import in that review fix; `c8e0249` corrects it |
| B1 | B | Home | Done (with B2) | 170 pass + 27 skipped, analyzer at baseline, all `home_*` captures OK |
| B2 | B | Collection card | Done (with B1) | 60-character titles shown in full at 320px and 2.0 text scale |
| B3 | B | Collection detail and lists | Done | Analyzer at baseline, `collection_detail__*` OK. Deck rows stay eager (two existing tests rely on it); title text scale capped at 1.4 to prevent mid-word breaks |
| E1 | E | Statistics | Done | 190 pass + 27 skipped, analyzer at baseline, all `stats_*` captures OK, full-length view reviewed |
| E2 | E | CSV import | Done | 235 pass + 28 skipped, analyzer at baseline, preview state added to harness and reviewed, import failure wording checked against the transaction |
| E3 | E | Profile and settings | Done | Analyzer at baseline, `profile__*` and `settings__*` OK with a signed-in user. Phone PNGs reviewed by Opus |
| E4 | E | Auth, legal, not found | Done | Analyzer at baseline, `auth__*` and `not_found__*` OK. `auth__phone` reviewed by Opus. Its missing logo is a harness artefact: a probe showed `memflow.png` decodes with `cacheWidth` once real async time passes, and the harness captures before that |
| D2 | D | Motion and performance pass | Done | 416 pass + 28 skipped, analyzer at baseline, overflow report unchanged. Page transition 220ms, tab fade 120ms, one unguarded `ExpansionTile` fixed. Hero dropped, as the plan allows: the detail page shows a skeleton first, so the flight has no destination on a first open. iOS and macOS keep the native 500ms slide, removed under reduced motion with swipe-back kept (test fails without the fix). Not checked on a device |
| F1 | F | Accessibility and regression tests | Done | 614 pass + 28 skipped, analyzer at baseline, overflow report unchanged with all 112 captures OK. Guidelines, size and text-scale matrix, reduced motion and 5 journey tests added. Fixed: readable error and destructive text, 48px cloze chips, centred wrapped button labels, no mode sheet slide under reduced motion |
| F2 | F | Profile-mode measurements | Stopped after an incident, needs the owner's go-ahead | Not run. No performance improvement is claimed. Unrun test code is uncommitted in `.claude/worktrees/agent-afaf4db05bda816b3` |
| Final review | Opus | Checklist and report | Done | See "Acceptance status" |

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

## Decisions needed from the product owner
- Study header progress dots: `progressDots` is a per-card count (3 to 6, from repetitions), but dots light up by session position, so they carry no real information. Options: remove them, or show repetitions against a fixed target. Left unchanged for now.

## Incident, 2026-11-01: real app removed from the owner's tablet
- At 00:31:35, F2 setup removed `com.memflow.app.memflow` (v2.4.0) from the SM-X406B, on all user profiles.
- Cause: `flutter test integration_test/perf_test.dart` was run as a supposed host dry run, before the package id was changed. It auto-selected the attached tablet, installed a debug build over the app, then uninstalled it.
- Impact: the tablet's local databases are gone. `LOCAL_STORAGE_SECURITY.md` states that a reinstall makes them unrecoverable, because the key is per installation. Only what had already synced to Supabase survives.
- Rule from now on: no integration test on a device holding real data until the built APK's package id is confirmed to differ, and only with the owner's go-ahead.
- Noted, not changed: the manifest doesn't disable Android Auto Backup, so a reinstall may restore an encrypted database or key file that can't be read. Effect on startup not tested.

## Known issues and blockers
- Remaining: F2 only, pending the owner's decision after the incident above.
- `showDialog`, `showModalBottomSheet`, `SnackBar` and the `NavigationBar` indicator use Material defaults (within 300ms), and Material doesn't remove them under reduced motion.

## Hypotheses to measure in F2 (no improvement claimed)
1. `home_screen.dart`, `_CollectionCard`: `IntrinsicHeight` and `Opacity` per row, layout time while scrolling 30+ collections.
2. `study_screen.dart`, flashcard flip: `Transform` and `AnimatedSize`, raster time.
3. `study_screen.dart`, feedback reveal: `Opacity`, `ClipRect` and `Align` per frame on long explanations.
4. `ui.dart`, `ProgressPill`: many pills rebuilding together on a stream update.
5. `router.dart`, tab fade over a full tab: raster time on a low-end device.
6. `home_screen.dart`, `SliverList.builder`: rebuild counts when `homeCollectionsProvider` re-emits after a sync.
- `/session-summary` "Refaire une session" builds `?collectionId=null` when both ids are null. Out of scope, to report.
- Forgot-password shows the "lien envoyé" snackbar even if the request failed. Out of scope, to report.
- Riverpod 3 retries failed stream providers by default, so error states may appear after a delay, with skeletons in the meantime. No app-wide `retry` config was added. To verify on a device.
- Out of scope, to report and not fix:
  - "Revoir mes erreurs" shows the mode sheet but ignores the choice.
  - `/study/errors` and `/session-summary` crash on direct links (null `extra`).
  - The email-change success message names the current address, while the dialog says the new one.
  - `sqlite3` is imported without being a direct dependency.
  - `md/instructions.md` still describes dark and light themes. Left as the historical original brief.

## Acceptance status (`refonte.md` §7)
Verified by tests and captures:
- One light identity, palette values unchanged and tested, no `Color(0x` outside `app_theme.dart`.
- No dark or Vivid theme in `lib/`.
- Logo kept. Features and journeys preserved: `study_controller.dart` and `study_rules.dart` are unchanged since the baseline, and in `lib/domain` only theme code and colours moved out. No change in `lib/data`.
- Consistent type, spacing, cards, icons and buttons, home hierarchy, mode distinction, charts without data, import and settings on the design system.

Not verified without a device:
- Real fluidity, layout stability during transitions, and the real keyboard.
- TalkBack, VoiceOver and the system reduce-motion setting.
- Performance on a real device: not measured.

## Remaining work
F2, then the device checks above.
