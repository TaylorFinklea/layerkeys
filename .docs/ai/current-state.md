# Current State

> Updated at the end of every work session. Read this first.

## Active Branch

`main`

## Last Session Summary

**Date**: 2026-04-20

- **Completed the Sonnet-tier `BindingRow` extraction** from the backlog
  (pre-M2 warmup). `NavigationBindingRow` + `NumpadBindingRow` unified
  into a single `BindingRow<Model: LayerBindingModel>` with fileprivate
  `LayerTargetKey` / `LayerBindingModel` protocols in `SettingsView.swift`.
  Marked the backlog item `[x]`. Single commit ready.
- **Completed M2: Configurable trigger** in three logical steps:
  - **M2.1 (model refactor)**: added `TriggerModifier` enum + `Set`
    extension for `CGEventFlags`, `TriggerProfile` struct, extended
    `MappingProfile` with `triggers: TriggerProfile` + custom
    `init(from:)` default-injecting on decode. `LayerStateMachine` now
    takes `TriggerProfile` and uses instance trigger properties;
    `EventTapEngine` wires the profile through. `AppModel` gained
    `updateTriggerProfile`.
  - **M2.2 (UI)**: new "Triggers" tab in Settings with a Category-grouped
    `InputKeyPicker` helper (now reused by `BindingRow`), ⌘⌃⌥⇧ modifier
    toggles, numpad sub-trigger picker, tap-to-Escape toggle, and a live
    chord preview. Removed the "Triggers are fixed in v1" copy from the
    Mappings tab. Status-menu instruction text is now derived from the
    live trigger profile via `TriggerProfile.chordSummary`.
  - **M2.3 (validation + polish)**: `TriggerValidationIssue` enum +
    `MappingProfile.validateTriggers()` returning warnings for empty
    modifiers on a typing-cluster key, sub-trigger = layer key, and
    sub-trigger colliding with a nav source. Warnings render inline in
    the Triggers tab. README "Current defaults" → "Defaults" rewritten
    to reflect configurability. `PermissionController` wording
    genericized to not hardcode "Control+Space".
- Key design decisions captured as ADRs in `decisions.md` (2026-04-20):
  trigger reuses `InputKey` (no new `TriggerKey` enum, no F-keys,
  no CapsLock, no modifier-only — consistent with M1); migration is
  default-inject on decode.
- `xcodebuild test` green: **28/28 passing** (11 pre-M1 + 5 M1 + 12 new
  M2). Zero warnings.
- Files touched this session: `LayerKeys/KeyCatalog.swift`,
  `LayerKeys/LayerStateMachine.swift`, `LayerKeys/EventTapService.swift`,
  `LayerKeys/AppModel.swift`, `LayerKeys/SettingsView.swift`,
  `LayerKeys/StatusMenuView.swift`, `LayerKeys/PermissionController.swift`,
  `LayerKeysTests/LayerKeysTests.swift`, `README.md`,
  `.docs/ai/roadmap.md`, `.docs/ai/current-state.md`,
  `.docs/ai/next-steps.md`, `.docs/ai/decisions.md`.

## Build Status

- App: debug build succeeds; all 28 tests pass on this macOS host.
- Release: still `0.1.0` — no release packaged this session. Bump + cut
  at the end of M4.

## Blockers

- None. Next session plans M3 (reliability & correctness).
