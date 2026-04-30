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

## Now / Next / Later

Active items. Trim as completed.

### Now
- **M4a Phase B.1** *(user action)* — at appleid.apple.com generate an app-specific password labeled `layerkeys-notarytool`. Then run `xcrun notarytool store-credentials layerkeys-notarytool --apple-id <your-apple-id> --team-id K7CBQW6MPG --password <app-specific-password>`. Unblocks Phase B.3 (real notarized local build) and Phase D.2 (same creds as GitHub Actions secrets).
- **M4a Phase B.3** — after B.1, run `./scripts/package_release.sh` end-to-end and confirm `xcrun stapler validate` + `spctl --assess --type execute -vv` both show "accepted" and "notarized". This is the real verification that the signing path works for distribution.

### Next
- **M4a Phase D.1** — `gh repo create TaylorFinklea/layerkeys --public --source . --push`. (Decision: probably public from day one because the cask URL is already public-facing. Confirm before running.)
- **M4a Phase D.2** — provision GitHub Actions secrets via `gh secret set`: `APPLE_DEVID_CERT_P12_BASE64` (`security export -k login.keychain -t identities -f pkcs12 ...` → `base64`), `APPLE_DEVID_CERT_PASSWORD`, `NOTARY_APPLE_ID`, `NOTARY_PASSWORD`, `NOTARY_TEAM_ID=K7CBQW6MPG`, `SPARKLE_EDDSA_PRIVATE_KEY` (`/tmp/sparkle-cli/bin/generate_keys -x -`).
- **M4a Phase D.3** — update `.github/workflows/release.yml` with cert-import-from-secrets, notarytool submit (Apple-ID creds path), and a `generate_appcast` step that uploads `appcast.xml` alongside `LayerKeys.zip`.
- **M4a Phase E** — bump `MARKETING_VERSION` to `0.2.0`, regenerate xcodeproj, commit, tag `v0.2.0`, push tag, watch CI, run `./scripts/update_homebrew_tap.sh` and push the tap repo.
- **M4a Phase F.1** — strip the `xattr -dr com.apple.quarantine` instruction from README; add a one-line "auto-updates via Sparkle" blurb in the install section.
- Visual smoke test of Phase A (Settings "General" tab, first-launch prompt, Check-for-Updates button) — open a debug build manually before tagging `v0.2.0`. Don't let CI ship a UI you've never seen.

### Later
- Backlog Sonnet-tier: extract the duplicated `add/remove/update*Binding` methods in `AppModel` into a generic over a `WritableKeyPath`. Good pre-M4b warmup once 0.2.0 is out.
- Backlog Haiku-tier: `MappingStore.swift` `try? save(.default)` silently swallows the migration save error. Route through the existing `lastError` plumbing.
- **M4b** items (post-0.2.0): full first-run onboarding wizard, conflict warnings in binding editor, hand-designed app icon refresh, marketing pass (README screenshots + GIF), non-US keyboard-layout glyph labels (deferred from M3), version bump to `1.0.0`.
- Backlog Opus-tier: investigate replacing `Thread` + `CFRunLoop` with a `DispatchQueue` / actor-wrapped `CFRunLoop`. Not until after M4b ships. Only pursue if a latency regression study shows it's worth the churn.
- "Advanced triggers" milestone (post-M4b): F-keys as triggers, CapsLock-as-trigger with remap-in-System-Settings help text, modifier-only triggers with left/right distinction. See `decisions.md` 2026-04-20 entry.
- Function keys as *targets* (not sources / not triggers). Still explicitly not a milestone. Revisit only if a real user asks.

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

### M2: Configurable trigger ✅

The trigger chord (`Control+Space`) and numpad sub-trigger (`A`) are
user-configurable, with tap-to-Escape exposed as a user toggle. Trigger key
is an `InputKey` (no F-keys, no CapsLock, no modifier-only — all deferred
to a hypothetical "advanced triggers" milestone to stay consistent with
M1's home-row identity; see `decisions.md` 2026-04-20).

- [x] `LayerStateMachine` reads `layerTriggerKeyCode`, `layerTriggerRequiredFlags`, and `numpadTriggerKeyCode` from a `TriggerProfile` value type instead of static lets — verified by all state-machine tests still passing plus `testLayerStateMachineUsesCustomTriggerKey`.
- [x] `MappingProfile` gains `triggers: TriggerProfile`, persisted in `UserDefaults`, with default-inject on decode via custom `init(from:)` — verified by `testMappingProfileDecodesPreM2JsonWithDefaultTriggers` and `testMappingProfileRoundTripsPreservingTriggers`.
- [x] Settings exposes a "Triggers" tab: layer-key picker (Category-grouped), modifier toggles (⌘ ⌃ ⌥ ⇧), numpad sub-trigger picker, tap-to-Escape toggle, live chord preview — verified manually.
- [x] Validation warnings surfaced inline in the Triggers tab: empty modifiers on a typing-cluster layer key, sub-trigger equal to layer key, sub-trigger colliding with a nav source — verified by `testTriggerValidationFlags*` tests.
- [x] Tap-to-Escape is a user toggle (default on); state machine reads `tapToEscapeEnabled` — verified by `testTapToEscapeDisabledViaTriggerProfile`.
- [x] README + Settings + StatusMenu copy updated; the "Triggers are fixed in v1" string is gone; the status-menu instruction text is now derived from the live trigger profile.

### M3: Reliability & correctness pass ✅

Make the tap survive every weird thing macOS throws at it. Non-US
keyboard-layout glyph labels were **deferred** (scope-creep: they need
Carbon/TIS glue and are a UI refinement, not a reliability fix — folded
into M4 polish; see `decisions.md` 2026-04-20 entry).

- [x] Tap re-enables on `tapDisabledByTimeout` / `tapDisabledByUserInput` (engine-thread `reEnableTapOnThread()`) and recovers on `NSWorkspace.didWakeNotification` via `SleepWakeHandler` (falls back to `stop()` + `start()` if `CGEvent.tapIsEnabled` returns false after re-enable) — verified by 4 new `testSleepWake*` tests covering both happy path and "tap died during sleep" fallback.
- [x] `Unmanaged` / retention audit — after the seam refactor there is exactly one `Unmanaged.passRetained(event)` site (the `.remap` branch of `handle`), one mutation path, and the ownership contract is obvious. Findings captured in `current-state.md` 2026-04-20.
- [x] Testable seam on `EventTapEngine.handle` — extracted a pure `LayerStateMachine.decide(...)` returning `EventDecision(action: EventAction, modeDidChange: Bool)`. The engine now dispatches the action to CGEvent side effects. 10 new `testDecide*` tests cover synthetic-escape suppression, trigger chord entry, wrong-modifier rejection, quick-tap Escape, tap-to-Escape toggle off, nav-remap, numpad-remap, sub-trigger consume, no-layer pass-through, and unrelated event-type pass-through.
- [x] CapsLock state during hold doesn't break tap-to-Escape — verified by `testCapsLockDuringHoldDoesNotSuppressTapToEscape` plus 4 `testOutputFlags*` hygiene tests asserting the trigger modifier set is stripped, `.maskSecondaryFn` is always stripped, and non-trigger modifiers (`.maskShift`, `.maskAlphaShift`) pass through untouched.
- [x] **Pre-M3 warmup**: extracted `EventTapEngine` + `EventTapStartup` (and the new `TapLivenessProbe`) from `EventTapService.swift` into `LayerKeys/EventTapEngine.swift`. Sonnet-tier backlog item `[x]`.

### M4a: Release pipeline — signed, notarized, auto-updating (ships 0.2.0)

The distribution milestone. Goal: a stranger types `brew install --cask
TaylorFinklea/tap/layerkeys` on a fresh Mac, opens the app, sees no
Gatekeeper dialog and runs no `xattr`, and gets the in-app
"update available" prompt on the next release. UI is unchanged from M3.
M4 was originally one milestone; split into M4a (this) + M4b (UX polish)
on 2026-04-29 per `decisions.md` (rationale: different blast radii, want
to verify the pipeline independently of UX work).

**Phase A — pure in-app code (✅ shipped):**

- [x] Sparkle 2.x SPM dependency wired into `project.yml`; `SPUStandardUpdaterController` owned by `LayerKeysApp`; "Check for Updates…" exposed in both Settings and the menu-bar dropdown — verified by `xcodebuild test` 51/51 (commit `59f0ef0`).
- [x] `LaunchAtLoginController` wraps `SMAppService.mainApp` behind a `LaunchAtLoginStore` protocol (TDD'd against 4 tests); `AppModel` exposes `launchAtLoginEnabled` + `toggleLaunchAtLogin()`; Settings "General" tab carries the toggle; `NSAlert` first-launch prompt fires once via `didShowLaunchAtLoginPrompt` UserDefaults flag (commit `750cbd2`).
- [x] Real Sparkle EdDSA public key installed in `info.properties` (`l2ghc9Y6kQcCddTEo6oRIJ2KL3rrE1ji/Xz+i9bme70=`); private key stored in user keychain (commit `18f449b`).

**Phase B — Developer ID signing + notarization:**

- [x] **B.2**: `scripts/package_release.sh` always builds unsigned then signs with `codesign --options runtime --timestamp --deep --sign "$DEVELOPER_ID"`; submits via `xcrun notarytool submit --wait` (auto-picks keychain-profile vs Apple-ID-env-var auth); staples ticket; re-zips; verifies with `stapler validate` + `spctl --assess`. Local sign+verify path validated end-to-end (signed app passes `codesign --verify --deep --strict`); notarization itself awaits B.1 (commit `116a2e6`).
- [ ] **B.1** *(user action)*: `xcrun notarytool store-credentials layerkeys-notarytool --apple-id <id> --team-id K7CBQW6MPG --password <app-specific-password>` after generating an app-specific password at appleid.apple.com.
- [ ] **B.3**: run `./scripts/package_release.sh` end-to-end and confirm `xcrun stapler validate` + `spctl --assess --type execute -vv` both report "accepted" + "notarized".

**Phase D — GitHub repo + CI secrets:**

- [ ] `gh repo create TaylorFinklea/layerkeys --public --source . --push` to bring the local repo onto GitHub. (Cask URL already points there; the repo just doesn't exist yet.)
- [ ] Provision GitHub Actions secrets via `gh secret set`: `APPLE_DEVID_CERT_P12_BASE64`, `APPLE_DEVID_CERT_PASSWORD`, `NOTARY_APPLE_ID`, `NOTARY_PASSWORD`, `NOTARY_TEAM_ID=K7CBQW6MPG`, `SPARKLE_EDDSA_PRIVATE_KEY`.
- [ ] `.github/workflows/release.yml` updated: cert-import-from-secrets into a temp keychain, run `package_release.sh` (which signs + notarizes), generate `appcast.xml` via Sparkle's `generate_appcast`, upload both `LayerKeys.zip` and `appcast.xml` as release assets.

**Phase E — cut 0.2.0:**

- [ ] Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` to `0.2.0` in `project.yml`; regenerate xcodeproj.
- [ ] Tag `v0.2.0`; push tag; CI runs end-to-end and publishes the release.
- [ ] `./scripts/update_homebrew_tap.sh` rewrites the cask sha + version; commit + push the tap repo.
- [ ] Smoke test: `brew install --cask TaylorFinklea/tap/layerkeys` on a fresh setup; app opens with no Gatekeeper dialog; first-launch prompt appears once.

**Phase F — README + docs:**

- [ ] Remove the `xattr -dr com.apple.quarantine` instruction from README; add a one-line "LayerKeys checks for updates automatically" note.
- [x] **F.3**: handoff docs updated — M4 split logged in `decisions.md`, this milestone reflects Phase A→F resumption order, `current-state.md` and the roadmap's Now/Next/Later point at remaining phases.

### M4b: 1.0 polish — onboarding, conflict warnings, icon, marketing

Once M4a ships 0.2.0, M4b takes the app from "stranger can install it" to
"stranger sticks with it." UI work, no further pipeline changes.

- [ ] First-run onboarding window: explains the trigger chord, requests Input Monitoring + Accessibility permissions inline, and dismisses itself once both are granted — verified by deleting the app's TCC entries and relaunching. (Richer than M4a's launch-at-login one-shot; that prompt stays.)
- [ ] Conflict warnings in the binding editor: when two bindings share a source key, the row that "loses" gets a non-blocking warning chip — verified visually.
- [ ] App icon refresh — replace the `generate_app_icon.swift` placeholder with a deliberate icon set — verified visually at all required sizes.
- [ ] Marketing pass: README screenshots, GIF of nav/numpad in action, accurate permission language, link to landing copy.
- [ ] Non-US keyboard-layout glyph labels in Settings pickers (deferred from M3).
- [ ] Version bumped to `1.0.0` in `project.yml`, tagged `v1.0.0`, release published, Homebrew tap updated — verified by `brew install --cask TaylorFinklea/tap/layerkeys` on a fresh machine.

## Backlog

Self-contained items any agent can pick up. Tier hints are advice, not gating.

- [ ] `LayerKeys/MappingStore.swift:23` — `try? save(.default)` silently swallows the migration save error. Replace with `do/catch` that surfaces the error via the existing `lastError` plumbing (or at minimum logs via `os_log`). **Tier hint**: Haiku — mechanical.
- [x] `LayerKeys/SettingsView.swift` — unified `NavigationBindingRow` and `NumpadBindingRow` into a single generic `BindingRow<Model: LayerBindingModel>` with fileprivate `LayerTargetKey` / `LayerBindingModel` protocols (done 2026-04-20 as a pre-M2 warmup; verified by `xcodebuild test` 16/16).
- [ ] `LayerKeys/AppModel.swift:93-137` — the six `add/remove/update` binding methods duplicate logic across `navigation` and `numpad`. Extract a generic over a `WritableKeyPath` to `[Binding]` so the methods become two-line wrappers. **Tier hint**: Sonnet — some architectural judgment.
- [x] `LayerKeys/EventTapEngine.swift` — `EventTapEngine` + `EventTapStartup` extracted into their own file; `EventTapService.swift` now hosts only the service facade + `SleepWakeHandler` (done 2026-04-20 as pre-M3 warmup).
- [x] Unit-testable seam on `EventTapEngine.handle` — done 2026-04-20 as M3.1. Pure `LayerStateMachine.decide(...)` returns `EventDecision(action:modeDidChange:)`; 10 new `testDecide*` tests cover synthetic-escape suppression, keypad-flag round-trip, and every action branch.
- [ ] Investigate replacing the raw `Thread` + `CFRunLoop` in `EventTapEngine` with a `DispatchQueue`-driven CFRunLoop or a Swift actor wrapper, *only if* it doesn't regress latency. Capture findings even if we keep the current shape. **Tier hint**: needs Opus to scope.

## Priority Order

1. **M1** (source-key catalog) — unblocks M2 and is the lowest-risk capability win. ✅ shipped.
2. **M2** (configurable trigger) — depends on M1's expanded `InputKey`. ✅ shipped.
3. **M3** (reliability) — needed before we ask strangers to install via brew. ✅ shipped.
4. **M4a** (release pipeline, ships 0.2.0) — Gatekeeper-clean install + Sparkle auto-update + launch-at-login. *In progress*: Phase A shipped; Phase B awaits user-provisioned notarytool credential; Phases D–F follow.
5. **M4b** (1.0 polish, ships 1.0.0) — first-run onboarding, conflict warnings, hand-designed icon, marketing pass.

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
- All event-tap invariants in `AGENTS.md` (synthetic-escape tagging, modifier
  hygiene, numeric-pad flag, mode-change debouncing) must hold.
