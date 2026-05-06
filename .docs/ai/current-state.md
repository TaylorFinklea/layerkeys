# Current State

> Updated at the end of every work session. Read this first.

## Active Branch

`main`

## Last Session Summary

**Date**: 2026-05-06 (M4b — menu-bar icon redesign)

- **Brainstormed → speced → planned → implemented in one session.**
  Replaced the `Image(systemName:) + Text("LK"/"NAV"/"NUM")` menu-bar
  pair with a custom keycap-silhouette glyph in 7 visual states.
  Brainstorming via the visual companion (Option C, "keyboard cap as
  constant identity, content morphs by state") at
  `.superpowers/brainstorm/10345-1778066998/content/`. Spec committed
  at `bb8c581`, plan at `22e3ec5`.

- **Implementation in 11 TDD tasks dispatched to subagents** (one fresh
  Sonnet implementer per task + spec-compliance review + code-quality
  review). Each task ended with its own commit; the repo stayed
  shippable between commits. Final commit is `c87d5ea` (Task 10 wired
  MenuBarIconView into LayerKeysApp).

- **Architecture:**
  - **`LayerKeys/MenuBarIconView.swift`** *(new)* — SwiftUI `Canvas`
    drawing a 24-unit-viewBox keycap silhouette + per-variant inner
    content. `Variant.tint` tints denied orange, error red, others
    `.primary`. `.foregroundStyle(variant.tint)` propagates to
    `.foreground` shading on every stroke/fill. 174 lines.
  - **`resolveMenuBarVariant(mode:perm:tapErrorActive:updateAvailable:)`**
    — top-level pure function. Priority: error > denied > listen-only
    > mode. Update badge composes onto non-alert variants only.
  - **`AppModel`** gained two `@Published private(set)` flags
    (`tapErrorActive`, `updateAvailable`) + a `setUpdateAvailable(_:)`
    setter + a `menuBarVariant` computed property forwarding the four
    inputs to the resolver.
  - **`EventTapService`** gained an `onTapRecovered: (() -> Void)?`
    callback paired with the existing `onTapError`. `SleepWakeHandler`
    fires `onRecover` after either re-enable or restart-engine
    fallback yields a live tap.
  - **`SparkleUpdateObserver`** *(new class in
    `LayerKeysApp.swift`)* — `NSObject` + `SPUUpdaterDelegate`. Bridges
    `didFindValidUpdate` / `updaterDidNotFindUpdate` /
    `didFinishUpdateCycleFor` into `model.setUpdateAvailable`. Owned by
    `LayerKeysApp` so the Sparkle controller's weak delegate stays
    alive. Plan's draft signature included
    `didDismissUpdateAlertPermanently` which doesn't exist in
    Sparkle 2.9.1; removed.
  - **`LayerMode.menuBarLabel` / `LayerMode.symbolName`** deleted (no
    consumers after the wire-up).

- **Listen-only state is now visible in the menu bar.** Closes the M3
  visibility gap noted at the top of `decisions.md` 2026-04-20.

- **Tests**: 51 → 84. Added 33 tests across the 11 tasks:
  - `SleepWakeHandler.onRecover` × 3
  - `AppModel.tapErrorActive` plumbing × 3
  - `AppModel.updateAvailable` + `SparkleUpdateObserver` × 3
  - `resolveMenuBarVariant` priority order × 11
  - `AppModel.menuBarVariant` × 3
  - `Variant.tint` and `Variant.accessibilityLabel` × 2
  - `MenuBarIconView` smoke renders × 7 (1 per variant + 2 badge composition)

- **Deviations from the plan, resolved inline by reviewers/implementers:**
  - Sparkle 2.9.1's `SPUUpdaterDelegate` doesn't have
    `didDismissUpdateAlertPermanently`. Removed; `didFinishUpdateCycleFor`
    covers the dismissed path.
  - `didFinishUpdateCycleFor` Swift import name is
    `updater(_:didFinishUpdateCycleFor:error:)`, not the plan's draft
    `didFinishUpdateCycleForUpdateCheck`.
  - Two `AppModel.menuBarVariant` tests needed an explicit
    `model.permissionState = .granted` to avoid CI's
    `PermissionController.currentState() == .denied` short-circuit.
  - Tests use smoke renders (`ImageRenderer.nsImage != nil`) instead of
    the spec's pixel-byte snapshots — pixel snapshots in macOS XCTest
    are fragile across OS/Xcode versions, and the high-value
    regressions (state-mapping bugs, accidental crashes) are caught by
    the resolver tests + smoke renders. Visual correctness is verified
    by the Task 11 manual smoke test.

- **Worth keeping in mind:**
  - Reviewer noted `LayerKeysApp.swift` now has 4 responsibilities
    (`@main App` / `CheckForUpdatesViewModel` / `CheckForUpdatesView` /
    `SparkleUpdateObserver`); extracting `SparkleUpdateObserver.swift`
    is reasonable polish for a future cleanup pass.
  - `SparkleUpdateObserver`'s delegate methods wrap `setAvailable` in
    `Task { @MainActor in ... }`. Sparkle docs say delegates fire on
    main, so this is over-defensive. Marking the class itself
    `@MainActor` would let those `Task` hops drop.
  - `MenuBarIconView`'s `drawInnerContent` is 75 lines with all 6
    variants. Cohesive at this size. If a future task adds animation
    or hit-testing per variant, consider extracting per-variant draw
    helpers.
  - The literal `18` (menu-bar icon size) appears at 9 sites
    (production + 8 tests). A `static let menuBarSize: CGFloat = 18`
    on `MenuBarIconView` would centralize it if the size ever changes.

- **Files touched this session**:
  - `LayerKeys/MenuBarIconView.swift` *(new, 174 lines)*
  - `LayerKeys/EventTapService.swift` (onTapRecovered + SleepWakeHandler.onRecover)
  - `LayerKeys/AppModel.swift` (tapErrorActive, updateAvailable, setUpdateAvailable, menuBarVariant)
  - `LayerKeys/LayerKeysApp.swift` (SparkleUpdateObserver class + wire-up MenuBarIconView)
  - `LayerKeys/KeyCatalog.swift` (deleted LayerMode.menuBarLabel + .symbolName)
  - `LayerKeysTests/LayerKeysTests.swift` (+33 tests, +`import SwiftUI`)
  - `LayerKeys.xcodeproj/project.pbxproj` (xcodegen regen for new file)
  - `docs/superpowers/specs/2026-05-06-menubar-icon-design.md` *(new)*
  - `docs/superpowers/plans/2026-05-06-menubar-icon-redesign.md` *(new)*

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

- Tests: **84/84 green** (51 pre-M4b + 33 new across the menu-bar icon
  redesign tasks).
- Release: 0.2.0 shipped (M4a Phase E). Menu-bar icon redesign is
  unreleased — sitting on `main` past `v0.2.0`. The next public
  release that includes it will pick up the new icon automatically.

## Blockers

- **M4b menu-bar icon manual smoke test (needs you)**: launch the just-built
  debug app and walk all 7 visual states. Steps in
  `docs/superpowers/plans/2026-05-06-menubar-icon-redesign.md` Task 11.
  Build path:
  `~/Library/Developer/Xcode/DerivedData/LayerKeys-*/Build/Products/Debug/LayerKeys.app`.
- **M4a Phase E.4 (still pending)**: `brew install --cask
  TaylorFinklea/tap/layerkeys` on a setup that's never run LayerKeys
  before. Confirm: app opens with no Gatekeeper dialog, first-launch
  "Start LayerKeys at login?" alert appears once, menu-bar
  Check-for-Updates button is reachable.
- **Visual smoke test of M4a Phase A still deferred**: Settings "General"
  tab, first-launch `NSAlert`, menu-bar Check-for-Updates button — all
  compile cleanly and tests pass, but UI feel hasn't been eyeballed.
