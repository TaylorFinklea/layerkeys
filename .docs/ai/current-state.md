# Current State

> Updated at the end of every work session. Read this first.

## Active Branch

`main`

## Last Session Summary

**Date**: 2026-04-20 (continuation of the same calendar-day session that
shipped M2)

- **Pre-M3 warmup**: extracted `EventTapEngine` + `EventTapStartup` (and
  the new `TapLivenessProbe`) from `EventTapService.swift` into
  `LayerKeys/EventTapEngine.swift`. Regenerated the Xcode project with
  `xcodegen` so the new file is picked up. Marked the Sonnet-tier
  backlog item `[x]`.
- **Completed M3: Reliability & correctness pass** in three logical
  substeps, all green at each checkpoint:
  - **M3.1 (testable seam)**: added `EventAction` enum and
    `LayerStateMachine.decide(...)` returning `EventDecision(action:,
    modeDidChange:)`. `EventTapEngine.handle` now only dispatches the
    decision to CGEvent side effects. 10 new `testDecide*` tests cover
    synthetic-escape suppression, trigger-chord entry, wrong-modifier
    rejection, quick-tap Escape, tap-to-Escape-off behavior, nav-remap,
    numpad-remap, sub-trigger consumption, no-layer-active pass-through,
    and unrelated-event-type pass-through.
  - **M3.2 (sleep/wake recovery)**: new `SleepWakeHandler` value type +
    `NSWorkspace.willSleepNotification` / `didWakeNotification`
    observers on `EventTapService`. On wake, idempotently re-enables the
    tap; if `CGEvent.tapIsEnabled` still returns false, falls back to
    `stop()` + `start()`. Engine gained `reEnableTap()` and
    `isTapAlive()` cross-thread helpers plus `TapLivenessProbe`. 4 new
    `testSleepWake*` tests drive the handler directly with stubbed
    closures.
  - **M3.3 (CapsLock + flag-hygiene regression tests)**: promoted
    `outputFlags(for:)` to `LayerStateMachine` so it's testable without
    touching `CGEvent`. New tests:
    `testCapsLockDuringHoldDoesNotSuppressTapToEscape`,
    `testOutputFlagsAlwaysStripsMaskSecondaryFn`,
    `testOutputFlagsStripsDefaultTriggerControlModifier`,
    `testOutputFlagsStripsCustomModifierSet`,
    `testOutputFlagsPreservesCapsLockAndShift`.
  - **M3.4 (`Unmanaged` audit)**: after the seam refactor there is
    exactly one `Unmanaged.passRetained(event)` site — the `.remap`
    branch of `handle` — and it's the only mutation path. The ownership
    contract is now obvious at a glance; no fixes needed. Findings
    captured in `decisions.md` 2026-04-20 entry.
- **Deferred**: non-US keyboard-layout glyph labels in Settings.
  Originally an M3 sub-item; pushed to M4 polish (or later) per
  `decisions.md` 2026-04-20.
- `xcodebuild test` green: **47/47 passing** (28 pre-M3 + 19 new M3).
  Zero compiler warnings.
- Files touched this session:
  - `LayerKeys/EventTapEngine.swift` *(new)*
  - `LayerKeys/EventTapService.swift` (trimmed to the service +
    `SleepWakeHandler`)
  - `LayerKeys/LayerStateMachine.swift` (new `EventAction`,
    `EventDecision`, `decide(...)`, `outputFlags(for:)`)
  - `LayerKeysTests/LayerKeysTests.swift` (+19 tests)
  - `LayerKeys.xcodeproj/project.pbxproj` (xcodegen-regenerated)
  - `.docs/ai/roadmap.md`, `decisions.md`, `current-state.md`,
    `next-steps.md`

## Build Status

- App: debug build succeeds; all 47 tests pass on this macOS host.
- Release: still `0.1.0`. No release packaged this session — bump + cut
  at the end of M4.

## Blockers

- None. Next session plans M4 (notarized v1.0 + onboarding +
  launch-at-login + Sparkle + polish). This is the biggest milestone
  and has real external dependencies (Apple Developer ID cert
  provisioning, `notarytool` keychain profile, Sparkle EdDSA key,
  GitHub Action secrets). Expect the plan phase to front-load those.
