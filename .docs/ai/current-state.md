# Current State

> Updated at the end of every work session. Read this first.

## Active Branch

`main`

## Last Session Summary

**Date**: 2026-04-19

- **Completed M1: Source-key catalog expansion.** `InputKey` grew from 31
  to 49 cases: digits `1–0`, punctuation `` ` `` `-` `=` `[` `]` `\` `'`,
  and the ISO `§/±` key. Function keys were explicitly dropped (see
  `decisions.md` 2026-04-19 entry).
- Added `InputKey.Category` (`.letters` / `.digits` / `.punctuation` /
  `.iso`) plus a `cases(in:)` static helper. `.space` lives in
  `.punctuation`; the picker section is labeled "Punctuation & Space."
- Grouped the Settings "From" pickers in both `NavigationBindingRow` and
  `NumpadBindingRow` into sections using `Section` inside the `Picker`
  content. Flat list of 49 items would have been unusable.
- Added five tests: `testInputKeyDigitKeycodes`,
  `testInputKeyPunctuationKeycodes`, `testInputKeyISOSectionKeycode`,
  `testInputKeyAllCasesContainsEveryExpectedCase`,
  `testInputKeyCategoryGrouping`. Each keycode assertion is against the
  authoritative `kVK_*` constant from the macOS SDK header.
- `xcodebuild test` green (16/16) with zero warnings. No changes to
  `MappingProfile` JSON shape — existing stored profiles load unchanged,
  verified by the pre-existing migration test still passing.
- Files touched: `LayerKeys/KeyCatalog.swift`,
  `LayerKeys/SettingsView.swift`, `LayerKeysTests/LayerKeysTests.swift`,
  `.docs/ai/roadmap.md`, `.docs/ai/decisions.md`. `EventTapService`,
  `LayerStateMachine`, `MappingStore`, `AppModel`, and `Info.plist`
  untouched.

## Build Status

- App: debug build succeeds (`xcodebuild test` pipeline validated the full
  build path including code-signing).
- Tests: **16/16 passing** on this machine (macOS host) as of the run that
  closed this session.
- Release: still `0.1.0`. No new release packaged this session — M1 is a
  pure code addition; we bump + cut a release at the end of M4.

## Blockers

- None. Next session plans M2 (configurable trigger).
