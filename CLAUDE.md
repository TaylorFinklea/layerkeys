# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build, test, and release commands

```bash
# Run the XCTest suite
xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS'

# Run a single test
xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' \
  -only-testing:LayerKeysTests/LayerKeysTests/testSpaceTriggerEntersNavigationMode

# Release build
xcodebuild build -scheme LayerKeys -project LayerKeys.xcodeproj -configuration Release -destination 'platform=macOS'

# Package a distributable zip (writes dist/LayerKeys.zip + dist/LayerKeys.sha256)
./scripts/package_release.sh

# Rewrite the Homebrew cask in ../homebrew-tap after packaging
./scripts/update_homebrew_tap.sh
```

The Xcode project is generated from `project.yml` via XcodeGen (Swift 6, macOS 14+). Edit `project.yml` rather than the `.xcodeproj` when changing targets, build settings, or sources.

## Architecture

LayerKeys is a `LSUIElement` SwiftUI menu-bar app that installs a `CGEventTap` to implement two keyboard layers (navigation + numpad) triggered by holding `Control+Space`. There is no kernel extension or external daemon — all interception happens in-process via Quartz Event Services.

Control flow, in layers:

1. **UI (`LayerKeysApp`, `StatusMenuView`, `SettingsView`)** — `MenuBarExtra` renders the current `LayerMode` (off/nav/numpad) and a permission warning. `Settings` scene hosts the binding editor.
2. **`AppModel` (`@MainActor`)** — owns the `MappingProfile`, current `LayerMode`, permission state, and `EventTapService`. All binding mutations go through `saveMappings()` which persists to `UserDefaults` and then calls `restartEventTap()` so the tap reloads resolved mappings.
3. **`EventTapService` + private `EventTapEngine`** — `EventTapEngine` spins up a dedicated `Thread` (`LayerKeys.EventTap`) with its own `CFRunLoop` that owns the `CGEvent.tapCreate` handle. This isolation matters: the tap callback must not block the main thread, and tearing down requires `perform(on: thread)` to stop the run loop cleanly. `onModeChange` / `onTapError` hop back to `@MainActor` via `Task`.
4. **`LayerStateMachine`** — pure value type (no Quartz types beyond `CGEventFlags`) that tracks trigger-hold state. All layer transitions and the "tap Control+Space → Escape" heuristic (`escapeTapThreshold = 200 ms`) live here so they are trivially unit-testable without simulating CGEvents. `LayerKeysTests` exercises this directly.
5. **`KeyCatalog`** — the enum-based source of truth for every keycode (`InputKey`, `NavigationTargetKey`, `NumpadTargetKey`) and for `MappingProfile` → `ResolvedMappings` precomputation. In `numpad` mode, a source key falls back to the nav map if no numpad binding exists (`ResolvedMappings.remappedKeyCode`).
6. **`PermissionController`** — wraps `CGPreflightListenEventAccess` (Input Monitoring) and `CGPreflightPostEventAccess` (Accessibility). The app can run in `.listenOnly` state: remaps work, but tap-to-Escape replay is suppressed because posting synthetic events requires Accessibility.

### Event-tap invariants to preserve

- **Synthetic-escape tagging.** Replayed Escape events are tagged with `syntheticEscapeEventTag` (`0x4C4B455343`) on `.eventSourceUserData` so the tap skips them on re-entry. Never strip that tag or the app will loop.
- **Modifier hygiene.** `outputFlags(for:)` must remove both `.maskSecondaryFn` and `layerTriggerRequiredFlags` (Control) before posting/forwarding, otherwise downstream apps see a ghost Control chord.
- **Numeric-pad flag.** Keypad targets require `.maskNumericPad` on the event flags; non-keypad targets must have it cleared. `ResolvedMappings.targetRequiresNumericPadFlag` drives this.
- **Trigger chord.** The layer trigger only engages when `Control` is held at the moment `Space` goes down (`layerTriggerRequiredFlags = .maskControl`). Any other key press during the hold clears `shouldEmitEscapeOnTriggerKeyUp` so tap-to-Escape doesn't fire after real typing.
- **Mode transition callbacks.** Only notify `onModeChange` when `LayerStateMachine` reports an actual change — spurious callbacks will flicker the menu bar.

### Persistence and migration

`MappingStore` stores the JSON-encoded `MappingProfile` in `UserDefaults` under `mappingProfile`. `MappingProfile.legacyDefault` (which included `space → keypad0` and `; → keypadDecimal`) is auto-migrated to the current `MappingProfile.default` on load — preserve this migration if you change the default profile, and update `testLegacyStoredDefaultMigratesToCurrentDefault` accordingly.

## Release workflow

Versioning lives in `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) and is read by the scripts via `PlistBuddy` on `LayerKeys/Info.plist`. Typical bump:

1. Update `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`, regenerate the xcodeproj, and commit.
2. `./scripts/package_release.sh` → produces `dist/LayerKeys.zip` + `dist/LayerKeys.sha256`.
3. `./scripts/update_homebrew_tap.sh` → rewrites `../homebrew-tap/Casks/layerkeys.rb` with the new version + sha.
4. Commit both repos, tag the app repo `v<version>`, push tag → `.github/workflows/release.yml` uploads `LayerKeys.zip` to the GitHub release that the cask URL points at.

CI (`.github/workflows/ci.yml`) runs the XCTest suite on `macos-latest` for every push to `main` and every PR.

## Testing notes

- Tests target `LayerStateMachine`, `ResolvedMappings`, and `MappingStore` directly — add new coverage at these seams rather than trying to drive `CGEventTap` from tests.
- `MappingStore` is `@MainActor`; use `UserDefaults(suiteName:)` with a unique suite name and `removePersistentDomain` for isolation, as `testLegacyStoredDefaultMigratesToCurrentDefault` demonstrates.
