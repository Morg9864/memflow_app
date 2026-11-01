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
| F2 | F | Profile-mode measurements | Done, run by Opus | 12 timed runs and 2 rebuild runs on a Galaxy Tab S10 Lite (SM-X406B, 90Hz), baseline `55ade2e` against final. See "Performance results". The real app stayed unchanged across all runs. Also found and fixed a `Pressable` crash (`06e7476`) |
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
- Remaining: manual checks on a device, see "Acceptance status".
- `showDialog`, `showModalBottomSheet`, `SnackBar` and the `NavigationBar` indicator use Material defaults (within 300ms), and Material doesn't remove them under reduced motion.

## Performance results (F2)
Profile mode, 768 due cards, 3 runs per case, median with the run range. A difference is claimed only when the ranges don't overlap, and 3 runs is little data. The phone layout is simulated (413x660 logical) on tablet hardware. Nothing here describes a low-end phone. Raw data: `build/perf/`.

| Scenario, layout | Frames over 11.1ms (90Hz budget) | Frames over 16.7ms | Worst build | Worst raster |
|---|---|---|---|---|
| Tab switch, phone | 71 (66-74) to 0 (0-0) | 16 (15-18) to 0 (0-0) | 42.3 to 9.0ms | 18.4 to 6.7ms |
| Tab switch, tablet | 71 (67-73) to 0 (0-1) | 14 (14-18) to 0 (0-0) | 40.9 to 10.3ms | 16.5 to 10.5ms |
| Session, phone | 17 (16-22) to 11 (10-16): no measurable difference | 4 (3-7) to 2 (0-2) | 20.4 to 19.3ms: no measurable difference | 15.6 to 12.7ms: no measurable difference |
| Session, tablet | 23 (15-26) to 7 (7-7) | 8 (6-8) to 1 (0-2) | 20.2 to 17.5ms | 21.3 to 14.2ms |
| Home scroll, phone | 1 (1-1) to 0 (0-1): no measurable difference | 0 to 0 | 16.5 to 6.5ms | 8.8 to 7.6ms: no measurable difference |
| Home scroll, tablet | 0 to 0 (0-1): no measurable difference | 0 to 0 | 4.5 to 7.5ms (worse) | 9.0 to 10.1ms (worse) |

Measured regressions, all well under the 11.1ms budget:
- Typical build time (p50) rose in tab switches (0.71 to 1.42ms on phone) and in the session (0.57 to 1.18ms on phone).
- Home scroll: build p99 2.44 to 3.83ms on phone, 2.20 to 5.13ms on tablet. Tablet raster p90 6.12 to 6.51ms.

Other results:
- Memory (total PSS after the session): phone 257-261MB to 248-262MB, tablet 253-255MB to 253-255MB. No measurable difference.
- Profile APK: 101.7MB to 98.9MB.
- The session draws about 3 times as many frames as before (329 to 1,043 on phone), because of its new animations. Percentiles aren't comparable across such different frame sets, so compare missed-frame counts instead.
- Rebuild runs: each scenario's trace stops at about 15-16k events, so its counts are capped and aren't totals. Tab switching at baseline is dominated by route transitions (`SlideTransition`, `FadeTransition`), which no longer lead the list in the final version.
- Baseline test differences: the `sharedPreferencesProvider` import, and waiting for runtime fonts.

Earlier hypotheses:
1. `_CollectionCard` layout cost: the tablet's p99 build rose, but nothing misses the budget and the cause isn't isolated. No action.
2. Flashcard flip raster: not measured, because the session uses QCM only.
3. Feedback reveal: not isolated. The session still has 7-11 frames over 11.1ms, whose source is unidentified.
4. `ProgressPill` rebuilds on stream updates: not measurable, because the scenarios have no sync.
5. Tab fade raster cost: not supported. Worst raster 6.7ms on phone and 10.5ms on tablet, with 0 missed frames.
6. Home list rebuilds after sync: not measurable, for the same reason as 4.

No code change is justified by these numbers.

## Acceptance status (`refonte.md` §7)
Verified by tests and captures:
- One light identity, palette values unchanged and tested, no `Color(0x` outside `app_theme.dart`.
- No dark or Vivid theme in `lib/`.
- Logo kept. Features and journeys preserved: `study_controller.dart` and `study_rules.dart` are unchanged since the baseline, and in `lib/domain` only theme code and colours moved out. No change in `lib/data`.
- Consistent type, spacing, cards, icons and buttons, home hierarchy, mode distinction, charts without data, import and settings on the design system.

Not verified without a device:
- Real fluidity, layout stability during transitions, and the real keyboard.
- TalkBack, VoiceOver and the system reduce-motion setting.
- Performance on a low-end phone, and on a real phone: not measured. This mid-range tablet is measured, see "Performance results".

## Remaining work
Tablet-first phase below. Manual device checks above still apply.

## Tablet-first phase
The first pass was designed and reviewed only at phone width. The primary device is the Galaxy Tab S10 Lite: portrait, 880x1408 logical, S Pen. Plan: `/home/morgan/.claude/plans/quiet-growing-comet.md`.

Owner decisions: portrait first, S Pen input, 2x2 study answers, on-screen keyboard for free text, progress dots removed.

| Step | Scope | Status | Validation |
|---|---|---|---|
| 1 | Harness with tablet viewports, "before" captures | Done | 224 captures OK in `build/visual/tablet_before`. Findings: phone-sized type everywhere, empty middle in study, bottom bar on a tablet |
| 2 | Breakpoints, tablet type step, rail, `AppScaffold` | Done | `6287e57`. Rail at 600 and above, whole-theme type step of 1.15 |
| 3 | Study | Done | `9ad8058`, `d85394e`. 2x2 answers, side panel depends on width only, dots removed |
| 4 | Home and collection screens | Done | `bb7599e`. Columns follow available width and text scale, which fixed mid-word breaks beside the rail |
| 5 | Stats, import, profile, settings, remaining screens | Done | `5bfee1f`. Mode sheet, summary and auth reviewed, no change needed |
| 6 | Tests and docs | Done | 803 pass + 30 skipped, analyzer at baseline. Layout matrix and guidelines cover tablet sizes. All tablet captures OK. Phone and small captures: 56 compared with the starting state, 26 differ, only in the dots area |
| 6b | Fix found on the real tablet | Done | `4feaa71`. The tablet's system font scale is 1.15, which dropped home to one column and long answers out of the grid. Column minimum 290, grid limit 320, and 1.15 added to captures and the layout matrix. 916 pass + 30 skipped, phone captures unchanged |
| 7 | On the tablet | In progress | Release of `4feaa71` installed in place (2.4.0, 13:32:15), signing key matched. An earlier install of `75f01e1` opened signed in with data present. Waiting: owner's S Pen check, then portrait performance (6 runs, `.perf` APKs built and id-checked) |

Unchanged since `950d53e`: `study_controller.dart`, `study_rules.dart`. `lib/data` and `lib/domain` only lost `progressDots`.

Known issues:
- Not checked on a device: all of this phase, including S Pen tapping, scrolling and palm contact, and whether a pen tap on the free-text field opens the keyboard. Flutter's stylus handwriting is on by default on this Android version.
- Stylus tests simulate the pointer kind only.
- `_StudyProgressHeader` reads `MediaQuery.viewInsetsOf`, which inside the Scaffold body never sees the keyboard, so its level row probably never hides. Found during this phase, and left as is because fixing it changes phone behaviour.
- The rail assumes a right-handed user.
- The stats skeleton at tablet width was not rendered in a capture.
