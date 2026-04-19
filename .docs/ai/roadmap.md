# Roadmap

> Durable goals and milestones. Updated when scope changes, not every session.

## Vision

LayerKeys is a minimalist macOS menu-bar utility that gives any keyboard a
hold-to-activate **navigation layer** and a **numpad layer**, so users never
have to leave the home row to use arrows or type numbers — without Karabiner,
JSON config, or a kernel extension.

**Identity:** "nav + numpad, done right." We deliberately do **not** plan
user-defined layers, per-app rules, or leader-key/launcher behavior. Polish,
reliability, and zero-friction install are the long-term differentiators.

## Milestones

Sequenced capability-first, polish last. Each milestone closes when every box
is checked and the verification command passes.

### M1: Source-key catalog expansion ✅

Today only `a–z`, `; , . / Space` can act as layer source keys. M1 widens the
catalog so users can bind layer mappings onto more of their keyboard.
Function keys are **not** added — they fight the "home-row-only" product
thesis and, if they matter later, belong on the target side of the catalog
(see `decisions.md` 2026-04-19 entry).

- [x] Add digits `1–0` to `InputKey` (LayerKeys/KeyCatalog.swift) — verified by `testInputKeyDigitKeycodes` asserting each against its `kVK_ANSI_*` keycode.
- [x] Add bracket / quote / hyphen / equal / backtick / backslash punctuation (`[ ] ' ` `` ` `` `-` `=` `\`) to `InputKey` — verified by `testInputKeyPunctuationKeycodes`.
- [x] Add the ISO `§/±` key (keycode 0x0A) so non-US keyboards have one extra source — verified by `testInputKeyISOSectionKeycode`.
- [x] Add `InputKey.Category` (`.letters` / `.digits` / `.punctuation` / `.iso`) plus `cases(in:)` helper, and group the Settings `From` picker by section so the 49-case list is navigable — verified visually in the running app and by `testInputKeyCategoryGrouping`.
- [x] Default `MappingProfile.default` is unchanged — verified by `testDefaultNumpadProfileOnlyContainsNineDigitBindings` still passing.
- [x] Stored pre-M1 profiles continue to decode — verified by `testLegacyStoredDefaultMigratesToCurrentDefault` still passing (reordering existing cases is safe because `rawValue` is derived from case names).

### M2: Configurable trigger

The trigger chord (`Control+Space`) and numpad sub-trigger (`A`) are
hardcoded. M2 makes both user-configurable while preserving the "tap-trigger
emits Escape" semantics.

- [ ] `LayerStateMachine` reads `layerTriggerKeyCode`, `layerTriggerRequiredFlags`, and `numpadTriggerKeyCode` from a `TriggerProfile` value type instead of static lets — verified by all existing state-machine tests still passing.
- [ ] `MappingProfile` (or a sibling `TriggerProfile`) gains trigger fields, persisted in `UserDefaults`, with a migration that maps any pre-M2 profile onto today's defaults — verified by a new `testPreM2ProfileMigratesTriggerToDefaults` test.
- [ ] Settings exposes a "Triggers" tab letting users choose the trigger key (from an `InputKey`-or-modifier picker), required modifiers, and the numpad sub-trigger — verified by manual smoke test (set trigger to `CapsLock`, layer activates).
- [ ] Conflict guard: the chosen trigger key cannot also appear as a layer source key, and the numpad sub-trigger cannot also be a layer source — verified by a unit test on a `TriggerProfile.validate()` API.
- [ ] Tap-to-Escape replay still works on chord triggers (e.g. `⌃Space`) and is automatically disabled for triggers that don't make sense to "tap" (e.g. `CapsLock` alone) — verified by extending `LayerKeysTests`.
- [ ] README + Settings copy updated; the "Triggers are fixed in v1" string is gone.

### M3: Reliability & correctness pass

Make the tap survive every weird thing macOS throws at it.

- [ ] Tap re-enables itself on `tapDisabledByTimeout` *and* `tapDisabledByUserInput` (already partial) and recovers after wake from sleep / display-lock — verified by a manual sleep/wake smoke test plus a new test driving the engine's tap-disabled handler.
- [ ] Audit `EventTapEngine.handle` for `Unmanaged` / retain edge cases (the synthetic-escape tag check, returning `nil` vs `passUnretained` vs `passRetained`) — verified by code review notes captured in the phase report.
- [ ] Add a unit-testable seam for `EventTapEngine.handle` (e.g. inject a `CGEvent` factory or split into pure mapping + side-effect halves) so we can test the keypad-flag path and synthetic-escape suppression without a real CGEventTap — verified by new tests.
- [ ] Non-US layout sanity check: physical keycodes are layout-independent, but Settings labels currently assume US glyphs (`;`, `,`, `.`, `/`). Show the user's layout-localized glyph next to the rawValue label — verified visually on a non-US keyboard layout in System Settings.
- [ ] CapsLock state during a hold doesn't break tap-to-Escape replay — verified by a new test that injects `.maskAlphaShift` into the trigger-up flags.

### M4: Notarized v1.0 — onboarding, launch-at-login, polish

The shipping milestone. Goal: a stranger types `brew install --cask
TaylorFinklea/tap/layerkeys`, opens the app, and never sees a `xattr` command,
never reads the README, and is in the navigation layer within 30 seconds.

- [ ] Developer ID Application signing wired into `scripts/package_release.sh` and the `release.yml` workflow, with cert + private key stored as GitHub secrets — verified by `codesign -dv --verbose=4 LayerKeys.app` showing the team ID.
- [ ] `notarytool` integration in CI using a stored keychain profile (Apple ID / app-specific password / team ID as secrets); release artifact is stapled — verified by `xcrun stapler validate dist/LayerKeys.app` and `spctl --assess --type execute -vv` showing "accepted".
- [ ] README's `xattr` instruction is removed and the cask no longer needs `--no-quarantine`.
- [ ] Sparkle integrated with EdDSA-signed appcast hosted on the GitHub release; auto-update prompt appears on a new release — verified by manual upgrade from a prior tag.
- [ ] Launch-at-login via `SMAppService.mainApp.register()`, with a Settings toggle and clean unregister on disable — verified by login-item smoke test.
- [ ] First-run onboarding window: explains the trigger, requests Input Monitoring + Accessibility permissions inline, and dismisses itself once both are granted — verified by deleting the app's TCC entries and relaunching.
- [ ] Conflict warnings in the binding editor: when two bindings share a source key, the row that "loses" gets a non-blocking warning chip — verified visually.
- [ ] App icon refresh — replace the `generate_app_icon.swift` placeholder with a deliberate icon set — verified visually at all required sizes.
- [ ] Marketing pass: README screenshots, GIF of nav/numpad in action, accurate permission language, link to landing copy.
- [ ] Version bumped to `1.0.0` in `project.yml`, tagged `v1.0.0`, release published, Homebrew tap updated — verified by `brew install --cask TaylorFinklea/tap/layerkeys` on a fresh machine.

## Backlog (parallel, tiered by model capability)

<!-- tier3_owner: claude -->
<!-- Valid values: claude, codex, copilot, unassigned -->

These items are independent of the milestones and can be picked up in any
session by an agent of the appropriate tier. Run `/audit-backlog` to refill.

### Haiku (mechanical, no judgment)

- [ ] `LayerKeys/MappingStore.swift:23` — `try? save(.default)` silently swallows the migration save error. Replace with `do/catch` that surfaces the error via the existing `lastError` plumbing (or at minimum logs via `os_log`).

### Sonnet (some architectural judgment)

- [ ] `LayerKeys/SettingsView.swift:110-192` — `NavigationBindingRow` and `NumpadBindingRow` are structurally identical; extract a single generic `BindingRow<TargetKey: Hashable & Identifiable & CaseIterable>` to remove the duplication.
- [ ] `LayerKeys/AppModel.swift:93-137` — the six `add/remove/update` binding methods duplicate logic across `navigation` and `numpad`. Extract a generic over a `WritableKeyPath` to `[Binding]` so the methods become two-line wrappers.
- [ ] `LayerKeys/EventTapService.swift:64+` — the private `EventTapEngine` is ~210 lines and arguably the heart of the app; move it into its own `EventTapEngine.swift` file (still `internal`) so the service-vs-engine split is obvious from the project navigator.

### Opus (design skill, cross-cutting — owned by `tier3_owner`)

- [ ] Add a unit-testable seam to `EventTapEngine.handle` so the synthetic-escape tag round-trip and the `.maskNumericPad` flag transitions can be tested without a real CGEventTap (likely a `CGEvent`-factory injection or a pure `EventDecision` value returned from a separate function).
- [ ] Investigate replacing the raw `Thread` + `CFRunLoop` in `EventTapEngine` with a `DispatchQueue`-driven CFRunLoop or a Swift actor wrapper, *only if* it doesn't regress latency. Capture findings even if we keep the current shape.

## Priority Order

1. **M1** (source-key catalog) — unblocks M2 and is the lowest-risk capability win.
2. **M2** (configurable trigger) — depends on M1's expanded `InputKey`.
3. **M3** (reliability) — needed before we ask strangers to install via brew.
4. **M4** (v1.0 notarization + polish) — the public shipping milestone.

Backlog runs alongside any milestone.

## Constraints

- macOS 14 (Sonoma) and later, Swift 6, single in-process target. No kernel
  extensions, no external daemons, no XPC helpers.
- **Fully offline.** No analytics, no crash reporting, no network calls
  anywhere — except Sparkle's appcast fetch starting in M4.
- **Install/discovery via Homebrew cask only.** No DMG landing page, no Mac
  App Store (sandboxing is incompatible with global CGEventTap). Updates are
  delivered in-app via Sparkle once M4 lands.
- **Layer model stays minimal:** navigation + numpad only. No user-defined
  layers, no per-app rules, no leader-key/launcher behavior. New product
  ideas in those directions belong in a separate project.
- **Numpad falls back to nav** when a key has no numpad binding — preserve
  this behavior; it is intentional.
- All event-tap invariants in `CLAUDE.md` (synthetic-escape tagging, modifier
  hygiene, numeric-pad flag, mode-change debouncing) must hold.
