# Current State

> Updated at the end of every work session. Read this first.

## Active Branch

`main`

## Last Session Summary

**Date**: 2026-05-05 (afternoon — Phase D + E)

- **M4a Phase D shipped end-to-end.** `gh repo create
  TaylorFinklea/layerkeys --public --source . --push` (D.1); user
  provisioned all six GitHub Actions secrets (D.2): cert .p12 + password,
  notary Apple-ID + app-specific password + team ID, Sparkle EdDSA
  private key. `gh secret list` confirmed all 6 names. (Sparkle private
  key initially landed in `./-` because `generate_keys -x -` writes to a
  literal file named `-` rather than stdout — caught and re-set the
  secret from the file before deletion. Worth remembering for future
  Sparkle work.)

- **M4a Phase E shipped 0.2.0.** Three commits and one tag fight:
  - `8a16cc3` "Bump version to 0.2.0" — `MARKETING_VERSION` 0.1.0 → 0.2.0,
    `CURRENT_PROJECT_VERSION` 1 → 2, mirrored into `Info.plist`.
  - `ca94785` "Build LayerKeysApp on Swift 6.1.2 (Xcode 16.4)" — CI
    runner crashed in `silgen emitStoredPropertyInitialization` for
    `@StateObject private var model = AppModel()` because Swift 6.1.2's
    `@StateObject` autoclosure can't inherit `@MainActor` isolation when
    `AppModel.init` is `@MainActor`. Local Swift 6.2+ tolerates the
    pattern. Fix: move both stored-property initializations into an
    explicit `App.init()` where actor isolation is unambiguous.
  - `fa563f6` "Skip first-launch NSAlert under XCTest" — CI test runner
    timed out with "Test runner never began executing tests after
    launching" because LayerKeys.app launches as the test host, then
    AppModel's deferred Task fires `NSAlert.runModal()` which blocks the
    run loop on a fresh runner where `didShowLaunchAtLoginPrompt` is
    still false. Fix: skip the prompt when
    `XCTestConfigurationFilePath` env var is set.
  - Tag `v0.2.0` was moved twice (origin tag deleted + recreated) so
    that the published tag points at `fa563f6`. CI run `25397167560`
    succeeded in 1m56s — Apple notary returned Accepted in 23 seconds.
  - Release published with `LayerKeys.zip` sha256
    `8665e5595c2dde2a981adb7790346af96e2e12380db3f60a9e4c07046489d7cc`
    and `appcast.xml`.

- **Tap repo updated.** `TaylorFinklea/homebrew-tap@2831a88` "Add
  LayerKeys cask v0.2.0". The local tap repo had diverged from origin
  (1 stale local commit re-adding the 0.1.0 cask, 5 newer commits on
  origin); resolved by `git rebase origin/main` (clean, no conflicts)
  then amended the rebased commit to carry the 0.2.0 update. `brew
  fetch --cask TaylorFinklea/tap/layerkeys` resolved + verified the
  sha256 against the published GitHub asset.

- **Files touched this session**:
  - `LayerKeys/LayerKeysApp.swift` (explicit init for Swift 6.1.2)
  - `LayerKeys/AppModel.swift` (XCTest guard around first-launch prompt)
  - `project.yml` + `LayerKeys.xcodeproj/project.pbxproj` +
    `LayerKeys/Info.plist` (version 0.2.0)
  - `.docs/ai/roadmap.md`, `current-state.md`
  - `../homebrew-tap/Casks/layerkeys.rb` (0.2.0 + new sha256)

**Date**: 2026-05-05

- **M4a Phase B.3 — pipeline validated end-to-end.** User completed B.1
  (notarytool keychain profile `layerkeys-notarytool` provisioned).
  Ran `./scripts/package_release.sh` against the current `main`
  (still 0.1.0 — version bump is Phase E). Submission
  `ebfa983a-3402-4c4a-8f3b-d19233a33f13` accepted by Apple's notary
  service after ~1 minute of "In Progress" → "Accepted". `stapler`
  staple + validate worked; `spctl --assess --type execute --verbose=2`
  reports `accepted` / `source=Notarized Developer ID`. Universal
  binary signed with `Developer ID Application: Taylor Finklea
  (K7CBQW6MPG)`; Sparkle.framework's nested binaries (Autoupdate,
  Updater.app, Downloader.xpc, Installer.xpc) all `--prepared` →
  `--validated` under `--deep`. Final artifact:
  `dist/LayerKeys.zip` sha256
  `17190ae34f3a1476a1147d221e3772bae79ca5dc13d170ef95b4f521e79a4de1`.
  No code changes this session — the script written in B.2 just got
  its first real notarization round-trip.

**Date**: 2026-04-30

- **M4a Phase D.3 + F.1** — README install section dropped the `xattr -dr`
  workaround and now points at "Check for Updates…" / Sparkle for in-app
  updates; release-workflow section rewritten to reflect that CI does the
  signing + notarization. `.github/workflows/release.yml` rewritten to:
  cert-import-from-secrets into a temp keychain (search-list-prepended
  so timestamp service still resolves), run `package_release.sh` with
  the `NOTARY_*` env vars wired to GitHub secrets, fetch a pinned
  `Sparkle-2.9.1.tar.xz` and run `generate_appcast` against `dist/`
  with the EdDSA private key sourced from `SPARKLE_EDDSA_PRIVATE_KEY`,
  upload both `LayerKeys.zip` and `appcast.xml` as release assets. All
  shell interpolations of GitHub-context values are routed through
  `env:` blocks (no direct `${{ }}` in `run:` for any field that could
  carry attacker-controlled input).
  *Not exercised in CI yet* — first real run is gated on D.1 (repo
  create) + D.2 (secret provisioning). The `generate_appcast` flag set
  is best-effort; expect to iterate after the first run.

**Date**: 2026-04-29

- **Resumption planning**: prior session's M4 plan needed reordering — the
  original "Prerequisites (user-owned)" assumed all external creds (Dev ID
  cert, notarytool credential, Sparkle keys, GitHub repo + secrets) were in
  place. Reality: only the Dev ID cert was provisioned; the GitHub repo
  doesn't exist yet (cask URL has been pointing at a 404 since 0.1.0). M4 was
  split into M4a (release pipeline, ships 0.2.0) + M4b (1.0 polish, ships
  1.0.0); M4a was reordered into Phase A (in-app code, fully unblocked) →
  B–F (signing, Sparkle keys, GitHub bootstrap, release cut, docs). See the
  resumption section at the top of `~/.claude/plans/plan-it-out-drifting-lantern.md`
  and the corresponding ADRs in `decisions.md`.

- **M4a Phase A** *(in-app code, no external deps)* — shipped in two commits:
  - **A.1** (commit `59f0ef0` "Wire Sparkle 2.x updater"): added Sparkle 2.6.0
    SPM dependency to `project.yml` (resolved to 2.9.1 in `Package.resolved`),
    `SPUStandardUpdaterController` owned by `LayerKeysApp`, "Check for
    Updates…" exposed as both a Settings command and a menu-bar dropdown
    button. `SUPublicEDKey` was a placeholder pending Phase C.
  - **A.2–A.4** (commit `750cbd2` "Wire launch-at-login + Settings General
    tab"): TDD-built `LaunchAtLoginController` wrapping `SMAppService.mainApp`
    behind a `LaunchAtLoginStore` protocol (4 new tests using a fileprivate
    `StubLaunchAtLoginStore`); `AppModel` exposes `launchAtLoginEnabled` +
    `toggleLaunchAtLogin()`, persists a `didShowLaunchAtLoginPrompt`
    UserDefaults flag, and shows an `NSAlert` first-launch prompt via a
    deferred main-actor `Task`; new "General" Settings tab carries the toggle
    plus a Sparkle-update blurb.

- **M4a Phase C** *(Sparkle EdDSA keypair)* — shipped (commit `18f449b`
  "Install Sparkle EdDSA public key"). Downloaded
  `Sparkle-2.9.1.tar.xz` from sparkle-project.org, ran `bin/generate_keys`,
  installed the public key (`l2ghc9Y6kQcCddTEo6oRIJ2KL3rrE1ji/Xz+i9bme70=`)
  in `info.properties` of `project.yml`. The matching private key is in the
  user's macOS keychain (Sparkle stores it under
  `https://sparkle-project.org` / `ed25519-private-key`). `xcodebuild test`
  green; the expected "404 appcast" log from Sparkle on test run confirms
  Sparkle is wired end-to-end (the appcast doesn't exist yet because the
  GitHub repo isn't created — Phase D).

- **M4a Phase B.2** *(release script signing/notarization)* — shipped
  (commit `116a2e6` "Sign + notarize releases"). `scripts/package_release.sh`
  rewritten to:
  - Always build unsigned (CI parity), then sign explicitly post-build.
  - Auto-detect the Developer ID Application identity from the keychain
    (override via `DEVELOPER_ID` env var); fail fast if zero or multiple
    matches.
  - Sign with `codesign --force --options runtime --timestamp --deep
    --sign "$DEVELOPER_ID"` (hardened runtime, required for notarization).
  - `xcrun notarytool submit --wait` in dual-mode: keychain profile locally
    (`NOTARY_KEYCHAIN_PROFILE` defaults to `layerkeys-notarytool`), Apple ID
    env-var creds (`NOTARY_APPLE_ID` / `NOTARY_PASSWORD` / `NOTARY_TEAM_ID`)
    in CI.
  - `xcrun stapler staple` + re-zip + `stapler validate` + `spctl --assess`.
  - Two escape hatches: `SKIP_CODESIGN=1` (unsigned) and `SKIP_NOTARIZE=1`
    (sign without submitting).
  - Local end-to-end validation: `SKIP_NOTARIZE=1 ./scripts/package_release.sh`
    succeeded. `codesign -dv --verbose=4` reports `flags=0x10000(runtime)`,
    universal binary (x86_64 + arm64), authority `Developer ID Application:
    Taylor Finklea (K7CBQW6MPG)`. Sparkle.framework's nested binaries
    (Autoupdate, XPCServices, Updater.app) signed correctly under `--deep`.
    Notarization itself **not yet verified** — awaits Phase B.1.

- **Files touched this session**:
  - `project.yml` (Sparkle dep + SUPublicEDKey)
  - `LayerKeys/LayerKeysApp.swift` (Sparkle wiring, CheckForUpdatesView)
  - `LayerKeys/StatusMenuView.swift` (accepts updater + Check-for-Updates button)
  - `LayerKeys/AppModel.swift` (launch-at-login state + first-launch prompt)
  - `LayerKeys/SettingsView.swift` (General tab)
  - `LayerKeys/LaunchAtLoginController.swift` *(new)*
  - `LayerKeysTests/LayerKeysTests.swift` (+4 launch-at-login tests, +stub)
  - `scripts/package_release.sh` (signing + notarization + stapling)
  - `LayerKeys.xcodeproj/project.pbxproj` + `project.xcworkspace/.../Package.resolved` (xcodegen + SPM)
  - `LayerKeys/Info.plist` (regenerated)
  - `.docs/ai/roadmap.md`, `decisions.md`, `current-state.md`

## Build Status

- Tests: **51/51 green** (47 pre-M4a + 4 new `LaunchAtLoginController` tests).
- Release script: signing path validated end-to-end locally via
  `SKIP_NOTARIZE=1`. Notarization path code-complete but not yet exercised.
- Release: still `0.1.0`. Bump to `0.2.0` happens in Phase E.

## Blockers

- **Phase E.4 (end-user smoke test) needs you**: `brew install --cask
  TaylorFinklea/tap/layerkeys` on a setup that's never run LayerKeys
  before. Confirm: app opens with no Gatekeeper dialog, first-launch
  "Start LayerKeys at login?" alert appears once, menu-bar
  Check-for-Updates button is reachable. After this, M4a is fully
  closed and M4b can begin.
- **Visual smoke test deferred**: I haven't actually launched the debug app
  to confirm the Settings "General" tab renders correctly, the first-launch
  `NSAlert` fires from a deferred main-actor `Task`, and the menu-bar
  Check-for-Updates button shows up. All compile cleanly and tests pass, but
  UI feel hasn't been eyeballed. No system-state-changing prompts (Input
  Monitoring, login-item registration) have been triggered.
