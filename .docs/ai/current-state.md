# Current State

> Updated at the end of every work session. Read this first.

## Active Branch

`main`

## Last Session Summary

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

- **Phase B.1 needs you**: at appleid.apple.com generate an app-specific
  password, then run
  `xcrun notarytool store-credentials layerkeys-notarytool --apple-id <id> --team-id K7CBQW6MPG --password <app-specific-password>`.
  After that, B.3 (a real notarized build) is one `./scripts/package_release.sh`
  away.
- **Phase D needs decisions**: should `TaylorFinklea/layerkeys` be public from
  day one (probably yes — the cask URL is already public-facing)? Once the
  repo exists, GitHub Actions secrets (cert .p12 base64, cert password,
  notary creds, Sparkle private key) need provisioning before Phase E can
  cut a real CI release.
- **Visual smoke test deferred**: I haven't actually launched the debug app
  to confirm the Settings "General" tab renders correctly, the first-launch
  `NSAlert` fires from a deferred main-actor `Task`, and the menu-bar
  Check-for-Updates button shows up. All compile cleanly and tests pass, but
  UI feel hasn't been eyeballed. No system-state-changing prompts (Input
  Monitoring, login-item registration) have been triggered.
