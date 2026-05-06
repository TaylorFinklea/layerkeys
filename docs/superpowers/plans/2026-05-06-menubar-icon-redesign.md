# Menu-bar icon redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the SF-Symbol + text-label menu-bar item with a 7-state custom keycap glyph rendered via SwiftUI, plumbing the two new state inputs (Sparkle update-available, event-tap error) needed for the full state set.

**Architecture:** New `MenuBarIconView` SwiftUI view drawn with `Canvas` from validated SVG path geometry. Pure `resolve(...)` function maps `(mode, perm, tapErrorActive, updateAvailable)` to a `(Variant, Bool)` tuple consumed at the menu-bar call site. Two new `@Published` properties on `AppModel` plus an `onTapRecovered` callback on `EventTapService` and a small `SparkleUpdateObserver` class provide the missing inputs.

**Tech Stack:** Swift 6, SwiftUI (`Canvas`, `MenuBarExtra`), Sparkle 2.x (`SPUUpdaterDelegate`), XCTest, XcodeGen (`project.yml`), CGEventTap (existing).

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `LayerKeys/MenuBarIconView.swift` | NEW | SwiftUI view + `Variant` enum + `resolve(...)` pure function. ~150 lines. |
| `LayerKeys/AppModel.swift` | MODIFY | Add `tapErrorActive` + `updateAvailable` `@Published` properties + `menuBarVariant` computed property. |
| `LayerKeys/EventTapService.swift` | MODIFY | Add `onTapRecovered: (() -> Void)?` callback. Fire from `SleepWakeHandler.didWake` recovery-success path. |
| `LayerKeys/LayerKeysApp.swift` | MODIFY | Replace `Image(systemName:) + Text(...)` pair (line 27) with `MenuBarIconView(...)`. Add `SparkleUpdateObserver` class + pass to `SPUStandardUpdaterController(updaterDelegate:)`. |
| `LayerKeys/KeyCatalog.swift` | MODIFY | Delete `LayerMode.menuBarLabel` and `LayerMode.symbolName` (no consumers after the icon swap). |
| `LayerKeysTests/LayerKeysTests.swift` | MODIFY | Add tests for `SleepWakeHandler.onTapRecovered`, `resolve(...)` priority order, `MenuBarIconView` smoke renders, and AppModel plumbing. |
| `.docs/ai/roadmap.md`, `.docs/ai/current-state.md`, `.docs/ai/next-steps.md`, `.docs/ai/decisions.md` | MODIFY | M4b icon redesign marked shipped; ADRs appended. |

`MenuBarIconView.swift` doubles as the home for both the rendering view and the pure resolution function so the two stay co-located. Splitting them across files would scatter the icon's logic without buying anything (both are <100 lines).

**Testing approach note (deviation from spec):** The spec describes pixel-byte snapshot tests via `ImageRenderer`. This plan uses **smoke render tests** (assert each variant renders to a non-nil NSImage at the expected size) plus exhaustive **pure-function tests** for `resolve(...)` and **data tests** for `Variant.tint` / `Variant.accessibilityLabel`. Reasoning: pixel snapshots in macOS XCTest are fragile across OS / Xcode / SwiftUI versions, and the high-value regressions (state-mapping bugs, accidental crashes from a bad path) are caught more reliably this way. Visual regression is covered by the manual smoke test in Task 11.

---

## Task 1: `EventTapService.onTapRecovered` callback

**Files:**
- Modify: `LayerKeys/EventTapService.swift`
- Test: `LayerKeysTests/LayerKeysTests.swift`

`SleepWakeHandler` already has a recovery path (call `reEnableTap`, fall back to `restartEngine` if the tap is dead). Today recovery is silent. We add an `onRecover` closure to `SleepWakeHandler`, fire it after either branch yields a live tap, and surface a parallel `onTapRecovered` callback on `EventTapService`.

- [ ] **Step 1: Write the failing test for `SleepWakeHandler.onRecover`**

Add to `LayerKeysTests/LayerKeysTests.swift`:

```swift
// MARK: - SleepWakeHandler

func testSleepWakeHandlerFiresOnRecoverAfterReEnableSucceeds() {
    var reEnableCount = 0
    var aliveSequence = [false, true]   // first probe: dead; second probe: alive after re-enable
    var recoveredCount = 0
    var errorMessages: [String] = []

    var handler = SleepWakeHandler(
        reEnableTap: { reEnableCount += 1 },
        isTapAlive: {
            let next = aliveSequence.removeFirst()
            return next
        },
        restartEngine: { XCTFail("restartEngine should not be called when re-enable revives the tap") },
        onError: { errorMessages.append($0) },
        onRecover: { recoveredCount += 1 }
    )

    handler.willSleep()
    handler.didWake()

    XCTAssertEqual(reEnableCount, 1)
    XCTAssertEqual(recoveredCount, 1)
    XCTAssertTrue(errorMessages.isEmpty)
}

func testSleepWakeHandlerFiresOnRecoverAfterRestartEnginePath() {
    var reEnableCount = 0
    var restartCount = 0
    var aliveSequence = [false, false, true]  // dead after re-enable AND after restart probe... then alive
    var recoveredCount = 0

    var handler = SleepWakeHandler(
        reEnableTap: { reEnableCount += 1 },
        isTapAlive: { aliveSequence.removeFirst() },
        restartEngine: { restartCount += 1 },
        onError: { _ in },
        onRecover: { recoveredCount += 1 }
    )

    handler.willSleep()
    handler.didWake()

    XCTAssertEqual(reEnableCount, 1)
    XCTAssertEqual(restartCount, 1)
    XCTAssertEqual(recoveredCount, 1)
}

func testSleepWakeHandlerSkipsRecoverWhenNoSleepPending() {
    var recoveredCount = 0
    var handler = SleepWakeHandler(
        reEnableTap: { XCTFail("should not re-enable without a prior sleep") },
        isTapAlive: { true },
        restartEngine: { XCTFail("should not restart without a prior sleep") },
        onError: { _ in },
        onRecover: { recoveredCount += 1 }
    )

    handler.didWake()

    XCTAssertEqual(recoveredCount, 0)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testSleepWakeHandlerFiresOnRecoverAfterReEnableSucceeds`

Expected: build error — `SleepWakeHandler` has no `onRecover` parameter.

- [ ] **Step 3: Add `onRecover` to `SleepWakeHandler`**

Edit `LayerKeys/EventTapService.swift`. Replace the `SleepWakeHandler` struct (lines 5-27) with:

```swift
struct SleepWakeHandler {
    var reEnableTap: () -> Void
    var isTapAlive: () -> Bool
    var restartEngine: () -> Void
    var onError: (String) -> Void
    var onRecover: () -> Void

    private(set) var sleepPending = false

    mutating func willSleep() {
        sleepPending = true
    }

    mutating func didWake() {
        guard sleepPending else { return }
        sleepPending = false

        reEnableTap()
        if isTapAlive() {
            onRecover()
            return
        }

        onError("Restarting event tap after sleep recovery.")
        restartEngine()

        if isTapAlive() {
            onRecover()
        }
    }
}
```

- [ ] **Step 4: Add `onTapRecovered` callback to `EventTapService` and route it through `installSleepWakeObservers`**

Same file. After line 31 (`var onTapError: ...`) add:

```swift
    var onTapRecovered: (() -> Void)?
```

Then update `installSleepWakeObservers(for:)` to wire the new closure. Replace the `SleepWakeHandler(` constructor call (around line 96) with:

```swift
        sleepWakeHandler = SleepWakeHandler(
            reEnableTap: { [weak engine] in engine?.reEnableTap() },
            isTapAlive: { [weak engine] in engine?.isTapAlive() ?? false },
            restartEngine: { [weak self] in
                guard let self else { return }
                self.stop()
                _ = self.start()
            },
            onError: { [weak self] message in
                self?.onTapError?(message)
            },
            onRecover: { [weak self] in
                self?.onTapRecovered?()
            }
        )
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testSleepWakeHandlerFiresOnRecoverAfterReEnableSucceeds -only-testing:LayerKeysTests/LayerKeysTests/testSleepWakeHandlerFiresOnRecoverAfterRestartEnginePath -only-testing:LayerKeysTests/LayerKeysTests/testSleepWakeHandlerSkipsRecoverWhenNoSleepPending`

Expected: PASS, 3 tests succeed.

- [ ] **Step 6: Run the full test suite**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS'`

Expected: PASS for all existing tests + 3 new ones.

- [ ] **Step 7: Commit**

```bash
git add LayerKeys/EventTapService.swift LayerKeysTests/LayerKeysTests.swift
git commit -m "$(cat <<'EOF'
Add EventTapService.onTapRecovered callback

SleepWakeHandler now fires onRecover() after a successful tap revival
(either re-enable alone or fallback restart). EventTapService surfaces
this as onTapRecovered: (() -> Void)? so AppModel can clear the
forthcoming tapErrorActive flag without polling.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `AppModel.tapErrorActive` plumbing

**Files:**
- Modify: `LayerKeys/AppModel.swift`
- Test: `LayerKeysTests/LayerKeysTests.swift`

Wire AppModel's existing `service.onTapError` closure to also flip a new `tapErrorActive` flag, and register an `onTapRecovered` closure that clears it.

- [ ] **Step 1: Write the failing tests**

Append to `LayerKeysTests/LayerKeysTests.swift`:

```swift
// MARK: - AppModel tapErrorActive

@MainActor
func testAppModelTapErrorActiveDefaultsFalse() {
    let service = EventTapService(profile: .default)
    let model = AppModel(eventTapService: service)
    XCTAssertFalse(model.tapErrorActive)
}

@MainActor
func testAppModelTapErrorActiveBecomesTrueOnTapError() async {
    let service = EventTapService(profile: .default)
    let model = AppModel(eventTapService: service)

    service.onTapError?("simulated tap death")
    await Task.yield()  // let the @MainActor Task scheduled by the closure run

    XCTAssertTrue(model.tapErrorActive)
}

@MainActor
func testAppModelTapErrorActiveBecomesFalseOnTapRecovered() async {
    let service = EventTapService(profile: .default)
    let model = AppModel(eventTapService: service)

    service.onTapError?("simulated tap death")
    await Task.yield()
    XCTAssertTrue(model.tapErrorActive)

    service.onTapRecovered?()
    await Task.yield()
    XCTAssertFalse(model.tapErrorActive)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testAppModelTapErrorActiveDefaultsFalse`

Expected: build error — `AppModel` has no `tapErrorActive` property.

- [ ] **Step 3: Add the property and wire the closures**

Edit `LayerKeys/AppModel.swift`. Add this `@Published` property right after line 11 (the other `@Published` declarations):

```swift
    @Published private(set) var tapErrorActive: Bool = false
```

Then update the `service.onTapError` closure (around line 44) and add a new `onTapRecovered` registration immediately after:

```swift
        service.onTapError = { [weak self] message in
            Task { @MainActor in
                self?.lastError = message
                self?.tapErrorActive = true
            }
        }
        service.onTapRecovered = { [weak self] in
            Task { @MainActor in
                self?.tapErrorActive = false
            }
        }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testAppModelTapErrorActiveDefaultsFalse -only-testing:LayerKeysTests/LayerKeysTests/testAppModelTapErrorActiveBecomesTrueOnTapError -only-testing:LayerKeysTests/LayerKeysTests/testAppModelTapErrorActiveBecomesFalseOnTapRecovered`

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add LayerKeys/AppModel.swift LayerKeysTests/LayerKeysTests.swift
git commit -m "$(cat <<'EOF'
Plumb tapErrorActive flag onto AppModel

Set true when EventTapService.onTapError fires, cleared when
onTapRecovered fires. Existing lastError string remains as-is for
the menu's text display; the new flag drives the upcoming
MenuBarIconView's .error variant.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `SparkleUpdateObserver` + `AppModel.updateAvailable`

**Files:**
- Modify: `LayerKeys/LayerKeysApp.swift` (add `SparkleUpdateObserver` class)
- Modify: `LayerKeys/AppModel.swift` (add `@Published` property + setter method)
- Test: `LayerKeysTests/LayerKeysTests.swift`

The Sparkle delegate methods land on the main thread. We surface a `setUpdateAvailable(_:)` method on AppModel rather than mutating `updateAvailable` directly from the observer — keeps the @MainActor boundary clean and avoids leaking `@Published` setters across actor isolation.

- [ ] **Step 1: Write the failing tests**

Append to `LayerKeysTests/LayerKeysTests.swift`:

```swift
// MARK: - AppModel updateAvailable

@MainActor
func testAppModelUpdateAvailableDefaultsFalse() {
    let model = AppModel(eventTapService: EventTapService(profile: .default))
    XCTAssertFalse(model.updateAvailable)
}

@MainActor
func testAppModelSetUpdateAvailableTogglesFlag() {
    let model = AppModel(eventTapService: EventTapService(profile: .default))

    model.setUpdateAvailable(true)
    XCTAssertTrue(model.updateAvailable)

    model.setUpdateAvailable(false)
    XCTAssertFalse(model.updateAvailable)
}

// MARK: - SparkleUpdateObserver

@MainActor
func testSparkleUpdateObserverInvokesSetAvailable() {
    var observed: [Bool] = []
    let observer = SparkleUpdateObserver(setAvailable: { observed.append($0) })

    // Drive the observer through its public closure-based init rather than
    // exercising SPUUpdaterDelegate methods directly — we don't want to
    // construct SUAppcastItem (which requires a complex dictionary in
    // Sparkle 2.x) just to verify a 1-line forwarder. The delegate methods
    // each call `setAvailable(true|false)` and are covered by the
    // `xcodebuild build` link step plus the manual smoke test in Task 11.
    observer.applyTrueForTesting()
    observer.applyFalseForTesting()

    XCTAssertEqual(observed, [true, false])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testAppModelUpdateAvailableDefaultsFalse`

Expected: build error — `AppModel` has no `updateAvailable` property and no `setUpdateAvailable(_:)` method, and `SparkleUpdateObserver` doesn't exist.

- [ ] **Step 3: Add the AppModel property + setter**

Edit `LayerKeys/AppModel.swift`. Add right after the `tapErrorActive` line from Task 2:

```swift
    @Published private(set) var updateAvailable: Bool = false
```

Add a method anywhere in the class body (e.g., right before `func quit()` at line 210):

```swift
    func setUpdateAvailable(_ available: Bool) {
        updateAvailable = available
    }
```

- [ ] **Step 4: Add the `SparkleUpdateObserver` class**

Edit `LayerKeys/LayerKeysApp.swift`. Append after the existing `CheckForUpdatesView` (after line 71):

```swift
final class SparkleUpdateObserver: NSObject, SPUUpdaterDelegate {
    private let setAvailable: @MainActor (Bool) -> Void

    init(setAvailable: @escaping @MainActor (Bool) -> Void) {
        self.setAvailable = setAvailable
        super.init()
    }

    convenience init(model: AppModel) {
        self.init { available in
            model.setUpdateAvailable(available)
        }
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Task { @MainActor in setAvailable(true) }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor in setAvailable(false) }
    }

    func updater(_ updater: SPUUpdater,
                 didDismissUpdateAlertPermanently permanently: Bool,
                 for item: SUAppcastItem) {
        Task { @MainActor in setAvailable(false) }
    }

    func updater(_ updater: SPUUpdater,
                 didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
                 error: Error?) {
        Task { @MainActor in setAvailable(false) }
    }

    #if DEBUG
    /// Test hooks. The Sparkle delegate methods each forward to one of these
    /// two paths; we expose them so unit tests don't have to construct an
    /// `SUAppcastItem` (whose public init in Sparkle 2.x requires a complex
    /// info-dictionary). Synchronous (no Task hop) so tests don't have to
    /// yield. Production code never calls these.
    @MainActor func applyTrueForTesting()  { setAvailable(true) }
    @MainActor func applyFalseForTesting() { setAvailable(false) }
    #endif
}
```

- [ ] **Step 5: Wire the observer into `LayerKeysApp.init()`**

Same file. Replace the existing `init()` body with:

```swift
    init() {
        let model = AppModel()
        let observer = SparkleUpdateObserver(model: model)
        _model = StateObject(wrappedValue: model)
        self.updaterObserver = observer
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: observer,
            userDriverDelegate: nil
        )
    }
```

And add the new stored property at the top of the struct, right after `updaterController` (between lines 7 and 8):

```swift
    private let updaterObserver: SparkleUpdateObserver
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testAppModelUpdateAvailableDefaultsFalse -only-testing:LayerKeysTests/LayerKeysTests/testAppModelSetUpdateAvailableTogglesFlag -only-testing:LayerKeysTests/LayerKeysTests/testSparkleUpdateObserverSetsAvailableOnFindValidUpdate`

Expected: PASS, 3 tests.

- [ ] **Step 7: Run the full test suite**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS'`

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add LayerKeys/AppModel.swift LayerKeys/LayerKeysApp.swift LayerKeysTests/LayerKeysTests.swift
git commit -m "$(cat <<'EOF'
Plumb Sparkle update-available state onto AppModel

SparkleUpdateObserver implements SPUUpdaterDelegate and bridges
didFindValidUpdate / didFinishUpdateCycleFor / didDismissUpdateAlert
into AppModel.setUpdateAvailable. The observer is owned by
LayerKeysApp so its lifetime is tied to the app, not the model.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `resolve(...)` pure function

**Files:**
- Create: `LayerKeys/MenuBarIconView.swift`
- Test: `LayerKeysTests/LayerKeysTests.swift`

The variant resolver is pure data; no SwiftUI yet. We start by creating the file with just the `Variant` enum and `resolve(...)` function so AppModel can compose against it in Task 5 before any rendering exists.

- [ ] **Step 1: Write the failing tests**

Append to `LayerKeysTests/LayerKeysTests.swift`:

```swift
// MARK: - resolveMenuBarVariant

func testResolveOffWhenIdleGrantedNoErrorNoUpdate() {
    let result = resolveMenuBarVariant(mode: .off, perm: .granted, tapErrorActive: false, updateAvailable: false)
    XCTAssertEqual(result.variant, .off)
    XCTAssertFalse(result.badge)
}

func testResolveOffBadgesWhenUpdateAvailable() {
    let result = resolveMenuBarVariant(mode: .off, perm: .granted, tapErrorActive: false, updateAvailable: true)
    XCTAssertEqual(result.variant, .off)
    XCTAssertTrue(result.badge)
}

func testResolveNavWhenNavGrantedNoErrorNoUpdate() {
    let result = resolveMenuBarVariant(mode: .nav, perm: .granted, tapErrorActive: false, updateAvailable: false)
    XCTAssertEqual(result.variant, .nav)
    XCTAssertFalse(result.badge)
}

func testResolveNumpadBadgesWhenUpdateAvailable() {
    let result = resolveMenuBarVariant(mode: .numpad, perm: .granted, tapErrorActive: false, updateAvailable: true)
    XCTAssertEqual(result.variant, .numpad)
    XCTAssertTrue(result.badge)
}

func testResolveListenOnlyOverridesMode() {
    let result = resolveMenuBarVariant(mode: .nav, perm: .listenOnly, tapErrorActive: false, updateAvailable: false)
    XCTAssertEqual(result.variant, .listenOnly)
    XCTAssertFalse(result.badge)
}

func testResolveListenOnlyBadgesWhenUpdateAvailable() {
    let result = resolveMenuBarVariant(mode: .off, perm: .listenOnly, tapErrorActive: false, updateAvailable: true)
    XCTAssertEqual(result.variant, .listenOnly)
    XCTAssertTrue(result.badge)
}

func testResolveDeniedOverridesMode() {
    let result = resolveMenuBarVariant(mode: .nav, perm: .denied, tapErrorActive: false, updateAvailable: false)
    XCTAssertEqual(result.variant, .denied)
    XCTAssertFalse(result.badge)
}

func testResolveDeniedNeverBadged() {
    let result = resolveMenuBarVariant(mode: .nav, perm: .denied, tapErrorActive: false, updateAvailable: true)
    XCTAssertEqual(result.variant, .denied)
    XCTAssertFalse(result.badge)
}

func testResolveErrorOverridesEverything() {
    let result = resolveMenuBarVariant(mode: .numpad, perm: .listenOnly, tapErrorActive: true, updateAvailable: true)
    XCTAssertEqual(result.variant, .error)
    XCTAssertFalse(result.badge)
}

func testResolveErrorOverridesDenied() {
    let result = resolveMenuBarVariant(mode: .off, perm: .denied, tapErrorActive: true, updateAvailable: false)
    XCTAssertEqual(result.variant, .error)
    XCTAssertFalse(result.badge)
}

func testResolveModeMappingCoversAllLayerModes() {
    XCTAssertEqual(resolveMenuBarVariant(mode: .off, perm: .granted, tapErrorActive: false, updateAvailable: false).variant, .off)
    XCTAssertEqual(resolveMenuBarVariant(mode: .nav, perm: .granted, tapErrorActive: false, updateAvailable: false).variant, .nav)
    XCTAssertEqual(resolveMenuBarVariant(mode: .numpad, perm: .granted, tapErrorActive: false, updateAvailable: false).variant, .numpad)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testResolveOffWhenIdleGrantedNoErrorNoUpdate`

Expected: build error — `resolveMenuBarVariant` and `MenuBarIconView.Variant` don't exist.

- [ ] **Step 3: Create `MenuBarIconView.swift` with the enum and resolver**

Create `LayerKeys/MenuBarIconView.swift`:

```swift
import SwiftUI

struct MenuBarIconView: View {
    enum Variant: Equatable {
        case off
        case nav
        case numpad
        case denied
        case listenOnly
        case error
    }

    let variant: Variant
    let updateBadge: Bool

    var body: some View {
        // Filled in by Task 6. Kept minimal so the type compiles for Task 4
        // (the resolver lives in this file too) and Task 5 (the AppModel
        // computed property references Variant).
        EmptyView()
    }
}

func resolveMenuBarVariant(
    mode: LayerMode,
    perm: InputMonitoringPermissionState,
    tapErrorActive: Bool,
    updateAvailable: Bool
) -> (variant: MenuBarIconView.Variant, badge: Bool) {
    if tapErrorActive { return (.error, false) }
    if perm == .denied { return (.denied, false) }
    if perm == .listenOnly { return (.listenOnly, updateAvailable) }
    switch mode {
    case .off:    return (.off, updateAvailable)
    case .nav:    return (.nav, updateAvailable)
    case .numpad: return (.numpad, updateAvailable)
    }
}
```

- [ ] **Step 4: Add the new file to `project.yml`**

Run from the repo root:

```bash
ls LayerKeys/MenuBarIconView.swift && xcodegen generate
```

Expected: file exists; `xcodegen` regenerates `LayerKeys.xcodeproj` and includes the new file via the existing `sources` glob.

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testResolveOffWhenIdleGrantedNoErrorNoUpdate -only-testing:LayerKeysTests/LayerKeysTests/testResolveErrorOverridesEverything`

Expected: PASS. Then run all eleven `testResolve*` tests:

`xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' | grep -E "testResolve|passed|failed"`

Expected: 11/11 PASS.

- [ ] **Step 6: Commit**

```bash
git add LayerKeys/MenuBarIconView.swift LayerKeys.xcodeproj LayerKeysTests/LayerKeysTests.swift
git commit -m "$(cat <<'EOF'
Add MenuBarIconView.Variant + resolveMenuBarVariant

Pure function maps (mode, perm, tapErrorActive, updateAvailable) to
(Variant, badge: Bool) following the priority order
error > denied > listenOnly > mode. Update badge composes onto the
non-alert variants but never onto error or denied.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `AppModel.menuBarVariant` computed property

**Files:**
- Modify: `LayerKeys/AppModel.swift`
- Test: `LayerKeysTests/LayerKeysTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `LayerKeysTests/LayerKeysTests.swift`:

```swift
// MARK: - AppModel.menuBarVariant

@MainActor
func testAppModelMenuBarVariantReflectsMode() {
    let model = AppModel(eventTapService: EventTapService(profile: .default))
    model.mode = .nav
    let result = model.menuBarVariant
    XCTAssertEqual(result.variant, .nav)
    XCTAssertFalse(result.badge)
}

@MainActor
func testAppModelMenuBarVariantHonorsErrorPriority() async {
    let service = EventTapService(profile: .default)
    let model = AppModel(eventTapService: service)
    model.mode = .numpad

    service.onTapError?("simulated")
    await Task.yield()

    XCTAssertEqual(model.menuBarVariant.variant, .error)
}

@MainActor
func testAppModelMenuBarVariantBadgeOnUpdateWhenSafe() {
    let model = AppModel(eventTapService: EventTapService(profile: .default))
    model.mode = .off
    model.setUpdateAvailable(true)

    XCTAssertEqual(model.menuBarVariant.variant, .off)
    XCTAssertTrue(model.menuBarVariant.badge)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testAppModelMenuBarVariantReflectsMode`

Expected: build error — `AppModel` has no `menuBarVariant` property.

- [ ] **Step 3: Add the computed property to `AppModel`**

Edit `LayerKeys/AppModel.swift`. Add somewhere in the class body (e.g., right before `func setUpdateAvailable` from Task 3):

```swift
    var menuBarVariant: (variant: MenuBarIconView.Variant, badge: Bool) {
        resolveMenuBarVariant(
            mode: mode,
            perm: permissionState,
            tapErrorActive: tapErrorActive,
            updateAvailable: updateAvailable
        )
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testAppModelMenuBarVariantReflectsMode -only-testing:LayerKeysTests/LayerKeysTests/testAppModelMenuBarVariantHonorsErrorPriority -only-testing:LayerKeysTests/LayerKeysTests/testAppModelMenuBarVariantBadgeOnUpdateWhenSafe`

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add LayerKeys/AppModel.swift LayerKeysTests/LayerKeysTests.swift
git commit -m "$(cat <<'EOF'
Expose AppModel.menuBarVariant computed property

Forwards the four state inputs to resolveMenuBarVariant. Call site
in LayerKeysApp can now subscribe to AppModel and let SwiftUI
recompute the icon whenever any input changes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `MenuBarIconView` body — cap shell + `.off` variant

**Files:**
- Modify: `LayerKeys/MenuBarIconView.swift`
- Test: `LayerKeysTests/LayerKeysTests.swift`

Replace the placeholder `EmptyView()` with the real Canvas-based renderer. Start with just the cap shell (rect + shelf line) and the `.off` inner content (single dim center dot) plus the `tint` and `accessibilityLabel` properties on `Variant`.

- [ ] **Step 1: Write the failing tests**

Append to `LayerKeysTests/LayerKeysTests.swift`:

```swift
// MARK: - MenuBarIconView.Variant data

func testVariantTintColors() {
    XCTAssertEqual(MenuBarIconView.Variant.off.tint,        .primary)
    XCTAssertEqual(MenuBarIconView.Variant.nav.tint,        .primary)
    XCTAssertEqual(MenuBarIconView.Variant.numpad.tint,     .primary)
    XCTAssertEqual(MenuBarIconView.Variant.listenOnly.tint, .primary)
    XCTAssertEqual(MenuBarIconView.Variant.denied.tint,     .orange)
    XCTAssertEqual(MenuBarIconView.Variant.error.tint,      .red)
}

func testVariantAccessibilityLabels() {
    XCTAssertEqual(MenuBarIconView.Variant.off.accessibilityLabel,        "LayerKeys, idle")
    XCTAssertEqual(MenuBarIconView.Variant.nav.accessibilityLabel,        "LayerKeys, navigation layer active")
    XCTAssertEqual(MenuBarIconView.Variant.numpad.accessibilityLabel,     "LayerKeys, numpad layer active")
    XCTAssertEqual(MenuBarIconView.Variant.denied.accessibilityLabel,     "LayerKeys, input monitoring permission denied")
    XCTAssertEqual(MenuBarIconView.Variant.listenOnly.accessibilityLabel, "LayerKeys, listen-only mode — tap-to-Escape disabled")
    XCTAssertEqual(MenuBarIconView.Variant.error.accessibilityLabel,      "LayerKeys, event tap error")
}

// MARK: - MenuBarIconView smoke render

@MainActor
func testMenuBarIconViewOffRendersToNonNilImage() {
    let view = MenuBarIconView(variant: .off, updateBadge: false)
        .frame(width: 18, height: 18)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0

    let image = renderer.nsImage
    XCTAssertNotNil(image, ".off variant must render to a non-nil NSImage")
    XCTAssertEqual(image?.size, CGSize(width: 18, height: 18))
}
```

Add `import SwiftUI` to `LayerKeysTests.swift` if it isn't already there:

```bash
grep -q "import SwiftUI" LayerKeysTests/LayerKeysTests.swift || sed -i.bak '1i\
import SwiftUI
' LayerKeysTests/LayerKeysTests.swift && rm -f LayerKeysTests/LayerKeysTests.swift.bak
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testVariantTintColors`

Expected: build error — `Variant.tint` and `Variant.accessibilityLabel` don't exist.

- [ ] **Step 3: Implement `Variant.tint` + `Variant.accessibilityLabel` and the cap-shell + `.off` render**

Replace the contents of `LayerKeys/MenuBarIconView.swift` with:

```swift
import SwiftUI

struct MenuBarIconView: View {
    enum Variant: Equatable {
        case off
        case nav
        case numpad
        case denied
        case listenOnly
        case error

        var tint: Color {
            switch self {
            case .denied: return .orange
            case .error:  return .red
            default:      return .primary
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .off:        return "LayerKeys, idle"
            case .nav:        return "LayerKeys, navigation layer active"
            case .numpad:     return "LayerKeys, numpad layer active"
            case .denied:     return "LayerKeys, input monitoring permission denied"
            case .listenOnly: return "LayerKeys, listen-only mode — tap-to-Escape disabled"
            case .error:      return "LayerKeys, event tap error"
            }
        }
    }

    /// Native viewBox the SVG paths were authored in. All draw calls happen
    /// in this 24-unit space and the Canvas scales to the actual size.
    private static let viewBox: CGFloat = 24

    let variant: Variant
    let updateBadge: Bool

    var body: some View {
        Canvas { ctx, size in
            let scale = min(size.width, size.height) / Self.viewBox
            ctx.scaleBy(x: scale, y: scale)

            drawCapShell(in: &ctx)
            drawInnerContent(in: &ctx)
            if updateBadge { drawUpdateBadge(in: &ctx) }
        }
        .foregroundStyle(variant.tint)
        .accessibilityLabel(variant.accessibilityLabel)
    }

    // MARK: - Drawing primitives

    private func drawCapShell(in ctx: inout GraphicsContext) {
        let cap = Path(roundedRect: CGRect(x: 3, y: 5, width: 18, height: 14),
                       cornerSize: CGSize(width: 2.5, height: 2.5))
        ctx.stroke(cap, with: .foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

        let shelf = Path { p in
            p.move(to: CGPoint(x: 3, y: 11))
            p.addLine(to: CGPoint(x: 21, y: 11))
        }
        ctx.stroke(shelf, with: .foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func drawInnerContent(in ctx: inout GraphicsContext) {
        switch variant {
        case .off:
            let dot = Path(ellipseIn: CGRect(x: 12 - 0.6, y: 15 - 0.6, width: 1.2, height: 1.2))
            ctx.fill(dot, with: .foreground)
        case .nav, .numpad, .denied, .listenOnly, .error:
            // Filled in by Tasks 7-9.
            break
        }
    }

    private func drawUpdateBadge(in ctx: inout GraphicsContext) {
        // Filled in by Task 9.
    }
}

func resolveMenuBarVariant(
    mode: LayerMode,
    perm: InputMonitoringPermissionState,
    tapErrorActive: Bool,
    updateAvailable: Bool
) -> (variant: MenuBarIconView.Variant, badge: Bool) {
    if tapErrorActive { return (.error, false) }
    if perm == .denied { return (.denied, false) }
    if perm == .listenOnly { return (.listenOnly, updateAvailable) }
    switch mode {
    case .off:    return (.off, updateAvailable)
    case .nav:    return (.nav, updateAvailable)
    case .numpad: return (.numpad, updateAvailable)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testVariantTintColors -only-testing:LayerKeysTests/LayerKeysTests/testVariantAccessibilityLabels -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewOffRendersToNonNilImage`

Expected: PASS, 3 tests.

- [ ] **Step 5: Run the full test suite**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS'`

Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add LayerKeys/MenuBarIconView.swift LayerKeysTests/LayerKeysTests.swift
git commit -m "$(cat <<'EOF'
Render MenuBarIconView cap shell + .off variant

Canvas-based draw loop scales the 24-unit viewBox to the actual frame,
strokes the rounded-rect cap + shelf line, and fills a single dim
center dot for the .off variant. Variant gains tint and
accessibilityLabel data properties consumed by the body.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Add `.nav` and `.numpad` variants

**Files:**
- Modify: `LayerKeys/MenuBarIconView.swift`
- Test: `LayerKeysTests/LayerKeysTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `LayerKeysTests/LayerKeysTests.swift`:

```swift
@MainActor
func testMenuBarIconViewNavRenders() {
    let view = MenuBarIconView(variant: .nav, updateBadge: false).frame(width: 18, height: 18)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0
    XCTAssertNotNil(renderer.nsImage)
}

@MainActor
func testMenuBarIconViewNumpadRenders() {
    let view = MenuBarIconView(variant: .numpad, updateBadge: false).frame(width: 18, height: 18)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0
    XCTAssertNotNil(renderer.nsImage)
}
```

- [ ] **Step 2: Run tests to verify they fail**

These tests will currently PASS because `drawInnerContent` falls through silently for `.nav` and `.numpad` — the cap shell still renders so `nsImage` is non-nil. We're not testing visual correctness with these (that's the manual smoke test in Task 11); these are smoke tests for "the case statement isn't crashing." Verify they pass NOW so we know the baseline:

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewNavRenders -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewNumpadRenders`

Expected: PASS (cap shell renders, no crash).

(*This task's test gate is "no regression on smoke renders after we add new draw code." We assert visual correctness by eyeballing during the Task 11 manual smoke test.*)

- [ ] **Step 3: Add the `.nav` and `.numpad` draw code**

Edit `LayerKeys/MenuBarIconView.swift`. Replace the body of `drawInnerContent(in:)` with:

```swift
    private func drawInnerContent(in ctx: inout GraphicsContext) {
        switch variant {
        case .off:
            let dot = Path(ellipseIn: CGRect(x: 12 - 0.6, y: 15 - 0.6, width: 1.2, height: 1.2))
            ctx.fill(dot, with: .foreground)

        case .nav:
            // 4-way directional cluster: cross + 4 chevrons, all within
            // x=9.5..14.5, y=12.5..17.5 (entirely inside the lower face).
            let stroke = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
            let cross = Path { p in
                p.move(to: CGPoint(x: 12,   y: 12.5)); p.addLine(to: CGPoint(x: 12,   y: 17.5))
                p.move(to: CGPoint(x: 9.5,  y: 15));   p.addLine(to: CGPoint(x: 14.5, y: 15))
            }
            ctx.stroke(cross, with: .foreground, style: stroke)
            let chevrons = Path { p in
                p.move(to: CGPoint(x: 10.8, y: 13.7)); p.addLine(to: CGPoint(x: 12, y: 12.5)); p.addLine(to: CGPoint(x: 13.2, y: 13.7))
                p.move(to: CGPoint(x: 10.8, y: 16.3)); p.addLine(to: CGPoint(x: 12, y: 17.5)); p.addLine(to: CGPoint(x: 13.2, y: 16.3))
                p.move(to: CGPoint(x: 10.7, y: 14.0)); p.addLine(to: CGPoint(x: 9.5,  y: 15)); p.addLine(to: CGPoint(x: 10.7, y: 16.0))
                p.move(to: CGPoint(x: 13.3, y: 14.0)); p.addLine(to: CGPoint(x: 14.5, y: 15)); p.addLine(to: CGPoint(x: 13.3, y: 16.0))
            }
            ctx.stroke(chevrons, with: .foreground, style: stroke)

        case .numpad:
            // 3x3 dot grid: cols x=8,12,16; rows y=13,15,17; r=0.7.
            let dotRadius: CGFloat = 0.7
            let columns: [CGFloat] = [8, 12, 16]
            let rows: [CGFloat] = [13, 15, 17]
            var grid = Path()
            for x in columns {
                for y in rows {
                    grid.addEllipse(in: CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    ))
                }
            }
            ctx.fill(grid, with: .foreground)

        case .denied, .listenOnly, .error:
            break  // Filled in by Tasks 8-9.
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewNavRenders -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewNumpadRenders -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewOffRendersToNonNilImage`

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add LayerKeys/MenuBarIconView.swift LayerKeysTests/LayerKeysTests.swift
git commit -m "$(cat <<'EOF'
Add nav and numpad inner content to MenuBarIconView

.nav draws a 4-way cluster (cross + 4 chevron tips) sized to fit
inside the lower face. .numpad draws a 3x3 dot grid with rows pulled
in to clear the cap floor.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Add `.denied` and `.listenOnly` variants

**Files:**
- Modify: `LayerKeys/MenuBarIconView.swift`
- Test: `LayerKeysTests/LayerKeysTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `LayerKeysTests/LayerKeysTests.swift`:

```swift
@MainActor
func testMenuBarIconViewDeniedRenders() {
    let view = MenuBarIconView(variant: .denied, updateBadge: false).frame(width: 18, height: 18)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0
    XCTAssertNotNil(renderer.nsImage)
}

@MainActor
func testMenuBarIconViewListenOnlyRenders() {
    let view = MenuBarIconView(variant: .listenOnly, updateBadge: false).frame(width: 18, height: 18)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0
    XCTAssertNotNil(renderer.nsImage)
}
```

- [ ] **Step 2: Run tests (will pass — smoke gate)**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewDeniedRenders -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewListenOnlyRenders`

Expected: PASS (cap shell already renders).

- [ ] **Step 3: Add the `.denied` and `.listenOnly` draw code**

Edit `LayerKeys/MenuBarIconView.swift`. Replace the `case .denied, .listenOnly, .error:` line at the end of `drawInnerContent(in:)` with:

```swift
        case .denied:
            // Diagonal slash from (5,6) to (19,18) at stroke-width 2.5.
            // Cap shell is already drawn (and tinted .orange via foregroundStyle);
            // the slash composes on top in the same color.
            let slash = Path { p in
                p.move(to: CGPoint(x: 5, y: 6))
                p.addLine(to: CGPoint(x: 19, y: 18))
            }
            ctx.stroke(slash, with: .foreground, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        case .listenOnly:
            // Six explicit dash segments, three per row, mathematically
            // centered around x=12. y rows at 14.5 and 17.
            let dashStroke = StrokeStyle(lineWidth: 1.7, lineCap: .round)
            let segments = Path { p in
                let xs: [(CGFloat, CGFloat)] = [(6, 8), (11, 13), (16, 18)]
                for y in [CGFloat(14.5), CGFloat(17)] {
                    for (x1, x2) in xs {
                        p.move(to: CGPoint(x: x1, y: y))
                        p.addLine(to: CGPoint(x: x2, y: y))
                    }
                }
            }
            ctx.stroke(segments, with: .foreground, style: dashStroke)

        case .error:
            break  // Filled in by Task 9.
        }
    }
```

(Replacing `case .denied, .listenOnly, .error:` with three separate cases. Keep the trailing `}` for the function intact.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewDeniedRenders -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewListenOnlyRenders`

Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add LayerKeys/MenuBarIconView.swift LayerKeysTests/LayerKeysTests.swift
git commit -m "$(cat <<'EOF'
Add denied and listenOnly variants to MenuBarIconView

.denied composes a diagonal slash on the cap (tinted orange via
Variant.tint). .listenOnly draws six explicit dash segments centered
on x=12 in two rows (no stroke-dasharray to keep symmetry exact).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Add `.error` variant + update badge composition

**Files:**
- Modify: `LayerKeys/MenuBarIconView.swift`
- Test: `LayerKeysTests/LayerKeysTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `LayerKeysTests/LayerKeysTests.swift`:

```swift
@MainActor
func testMenuBarIconViewErrorRenders() {
    let view = MenuBarIconView(variant: .error, updateBadge: false).frame(width: 18, height: 18)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0
    XCTAssertNotNil(renderer.nsImage)
}

@MainActor
func testMenuBarIconViewOffWithBadgeRenders() {
    let view = MenuBarIconView(variant: .off, updateBadge: true).frame(width: 18, height: 18)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0
    XCTAssertNotNil(renderer.nsImage)
}

@MainActor
func testMenuBarIconViewNavWithBadgeRenders() {
    let view = MenuBarIconView(variant: .nav, updateBadge: true).frame(width: 18, height: 18)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0
    XCTAssertNotNil(renderer.nsImage)
}
```

- [ ] **Step 2: Run smoke tests (still pass — cap shell renders)**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewErrorRenders -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewOffWithBadgeRenders -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewNavWithBadgeRenders`

Expected: PASS.

- [ ] **Step 3: Add the `.error` and update-badge draw code**

Edit `LayerKeys/MenuBarIconView.swift`. Replace `case .error: break` (the last case in `drawInnerContent(in:)`) with:

```swift
        case .error:
            // ✕: two crossed lines from (9,13.5)→(15,17.5) and (15,13.5)→(9,17.5).
            // Cap shell is tinted .red via foregroundStyle.
            let cross = Path { p in
                p.move(to: CGPoint(x: 9,  y: 13.5)); p.addLine(to: CGPoint(x: 15, y: 17.5))
                p.move(to: CGPoint(x: 15, y: 13.5)); p.addLine(to: CGPoint(x: 9,  y: 17.5))
            }
            ctx.stroke(cross, with: .foreground, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }
```

Then replace the empty `drawUpdateBadge(in:)` body with:

```swift
    private func drawUpdateBadge(in ctx: inout GraphicsContext) {
        // Corner badge: filled circle at (20, 6) r=3 with white ↓ glyph inside.
        // Sits in the upper-right outside the cap rect.
        let disc = Path(ellipseIn: CGRect(x: 17, y: 3, width: 6, height: 6))
        ctx.fill(disc, with: .foreground)

        let arrow = Path { p in
            p.move(to: CGPoint(x: 20,   y: 4.6))
            p.addLine(to: CGPoint(x: 20, y: 7.4))
            p.move(to: CGPoint(x: 18.7, y: 6.2))
            p.addLine(to: CGPoint(x: 20, y: 7.5))
            p.addLine(to: CGPoint(x: 21.3, y: 6.2))
        }
        ctx.stroke(arrow, with: .color(.white), style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round))
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewErrorRenders -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewOffWithBadgeRenders -only-testing:LayerKeysTests/LayerKeysTests/testMenuBarIconViewNavWithBadgeRenders`

Expected: PASS, 3 tests.

- [ ] **Step 5: Run full test suite**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS'`

Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add LayerKeys/MenuBarIconView.swift LayerKeysTests/LayerKeysTests.swift
git commit -m "$(cat <<'EOF'
Add error variant + update badge to MenuBarIconView

.error draws the ✕ crossed lines inside the cap (tinted red via
Variant.tint). drawUpdateBadge draws a filled corner disc with an
inset white ↓ arrow, composed on top of any non-alert base variant.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Wire `MenuBarIconView` into `LayerKeysApp` + delete old `LayerMode` strings

**Files:**
- Modify: `LayerKeys/LayerKeysApp.swift`
- Modify: `LayerKeys/KeyCatalog.swift`

- [ ] **Step 1: Replace the menu-bar label in `LayerKeysApp`**

Edit `LayerKeys/LayerKeysApp.swift`. Replace lines 23-32 (the `MenuBarExtra { ... } label: { ... }` block) with:

```swift
        MenuBarExtra {
            StatusMenuView(model: model, updater: updaterController.updater)
        } label: {
            MenuBarIconView(
                variant: model.menuBarVariant.variant,
                updateBadge: model.menuBarVariant.badge
            )
            .frame(width: 18, height: 18)
        }
        .menuBarExtraStyle(.window)
```

- [ ] **Step 2: Delete `LayerMode.menuBarLabel` and `LayerMode.symbolName`**

Edit `LayerKeys/KeyCatalog.swift`. Delete lines 281-301 (the two computed properties), keeping the closing `}` of `LayerMode` and the `title` property above. The enum should end with `var title: String { ... }` then the closing brace.

- [ ] **Step 3: Build to verify nothing else references the deleted properties**

Run: `xcodebuild build -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS'`

Expected: success. If any file errors with "unknown member 'menuBarLabel' / 'symbolName'", grep for it (`grep -rn "menuBarLabel\|symbolName" LayerKeys`) and remove those references too — there should be none after Step 1, but the spec called this out explicitly so we double-check.

- [ ] **Step 4: Run full test suite**

Run: `xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS'`

Expected: all tests green.

- [ ] **Step 5: Commit**

```bash
git add LayerKeys/LayerKeysApp.swift LayerKeys/KeyCatalog.swift
git commit -m "$(cat <<'EOF'
Replace menu-bar Image+Text with MenuBarIconView

The Image(systemName:) + Text("LK"/"NAV"/"NUM") pair becomes a single
MenuBarIconView driven off model.menuBarVariant. LayerMode.menuBarLabel
and LayerMode.symbolName are deleted — no remaining consumers.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Manual smoke test + docs updates

**Files:**
- Modify: `.docs/ai/roadmap.md`, `.docs/ai/current-state.md`, `.docs/ai/next-steps.md`, `.docs/ai/decisions.md`

This is the only manual gate in the plan. Visual correctness for all 7 variants is verified by eye.

- [ ] **Step 1: Build and run the app**

Run: `xcodebuild build -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS' && open build/Build/Products/Debug/LayerKeys.app` (or use Xcode's Run button if you prefer)

- [ ] **Step 2: Walk through the 7 states**

In the menu bar icon, verify each state is visually distinct and matches the brainstormed mockups:

1. **Off** — Empty cap with single dim center dot. (Default state on launch.)
2. **Nav** — Hold Control+Space (or whatever the configured trigger is). Icon swaps to a 4-way directional cluster inside the cap.
3. **Numpad** — While holding the layer trigger, hold the numpad sub-trigger (default is `j`). Icon swaps to a 3×3 dot grid.
4. **Permission denied** — System Settings → Privacy & Security → Input Monitoring → toggle LayerKeys off. Icon turns orange with a diagonal slash.
5. **Listen-only** — Restore Input Monitoring; turn off Accessibility for LayerKeys. Icon shows the dashed lower-face treatment in the default tint. (Today this state is invisible — verifying it appears confirms the M3 visibility-gap fix.)
6. **Update available** — Trigger a Sparkle check that finds an update (point `SUFeedURL` at a staging appcast referencing a newer version, or just install an older build of LayerKeys and let it check). Corner ↓ badge composes onto whatever base variant is active.
7. **Tap error** — Hardest to repro deterministically; either: (a) wait for a sleep/wake cycle that knocks the tap dead between, or (b) attach a debugger and break in `EventTapEngine.start()` to force an error path. Icon turns red with ✕ glyph.

If any variant looks wrong, fix the SVG path coordinates in `MenuBarIconView.swift` and re-build. The brainstormed mockups in `.superpowers/brainstorm/10345-1778066998/content/04-revised-variants.html` are the visual reference.

- [ ] **Step 3: Update `.docs/ai/roadmap.md`**

In the M4b section, add a checked entry for "Menu-bar icon redesign — 7 keycap-silhouette variants, drops the LK/NAV/NUM text label, plumbs Sparkle update + tap-error signals (fixes M3 listen-only visibility gap)." Mark the in-flight pointer to point at the next M4b item (icon refresh of `AppIcon.appiconset`, conflict warnings, or onboarding wizard depending on what's next in your queue).

- [ ] **Step 4: Update `.docs/ai/current-state.md`**

In the "Now" or "Just shipped" section, add: "M4b kicked off with the menu-bar icon redesign. Custom keycap glyph in 7 variants replaces SF Symbols + text label. New AppModel inputs: `tapErrorActive`, `updateAvailable`. Listen-only state is now visible in the menu bar — closes the known M3 gap."

- [ ] **Step 5: Update `.docs/ai/next-steps.md`**

Repoint to the next M4b item.

- [ ] **Step 6: Append ADRs to `.docs/ai/decisions.md`**

Add four ADR entries (use whatever heading style the file already uses — match it):

```markdown
## Custom keycap glyph for the menu-bar icon (M4b, 2026-05-06)

Generic SF Symbols collapsed onto each other at small sizes and gave us
no path to per-state tinting that didn't fight the system. A bespoke
silhouette is the small amount of design work that buys
ever-distinguishable state visualization. Specifically: the orange-tinted
permission-denied and red-tinted tap-error states require non-template
color, which template-image PDFs can't deliver without a SwiftUI tint
override that contradicts the asset's color baking.

## Path/Canvas rendering over template-image PDFs (M4b, 2026-05-06)

Single source of truth: the validated SVG paths translate directly to
Swift `Path` calls inside a `Canvas`. Per-variant tinting via
`.foregroundStyle` rather than baked into image variants. Trade-off
accepted: lose the automatic system tinting that template images get,
but we don't want it for orange/red states anyway.

## Drop the menu-bar text label (M4b, 2026-05-06)

State-distinct iconography makes the "LK"/"NAV"/"NUM" text redundant.
A glyph-only menu-bar item also matches every other macOS utility
convention. Today's hardcoded `LayerMode.menuBarLabel` and
`LayerMode.symbolName` are deleted; no consumers remain.

## Variant priority order: error > denied > listen-only > mode (M4b, 2026-05-06)

Errors and permissions are blocking; they preempt mode display.
Listen-only is a partial-failure mode where the layers still work, so
we show the listen-only marker but allow the mode signal to be
inferred from the user's interaction (they know whether they're
holding the trigger). Update badge composes on non-alert variants
only; stacking "update available" on top of "tap error" is incoherent.
```

- [ ] **Step 7: Commit docs**

```bash
git add .docs/ai/roadmap.md .docs/ai/current-state.md .docs/ai/next-steps.md .docs/ai/decisions.md
git commit -m "$(cat <<'EOF'
Mark M4b menu-bar icon redesign shipped; append ADRs

Roadmap, current-state, and next-steps updated. Four ADRs appended
covering: custom keycap glyph choice, Path/Canvas over template PDFs,
dropping the LK/NAV/NUM text label, and the variant priority order.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Notes

- **Spec coverage:** All 7 variants (off, nav, numpad, denied, listen-only, error, update-badge composition) are implemented in Tasks 6-9; both new AppModel inputs in Tasks 2 and 3; resolver and computed property in Tasks 4-5; wire-up + cleanup in Task 10; docs in Task 11. The known M3 listen-only visibility gap is fixed implicitly by Task 5 (`menuBarVariant` reads the full `permissionState` enum, not just `isGranted`) plus Task 8 (the listen-only inner content renders distinctly).
- **Testing approach deviation from spec:** The spec promised pixel-byte snapshot tests via `ImageRenderer`. The plan substitutes smoke render tests + exhaustive pure-function tests + manual visual smoke test. Justified inline at the top of the plan; flagged here so the implementer doesn't think this is an oversight.
- **Type consistency:** `MenuBarIconView.Variant`, `resolveMenuBarVariant`, and `menuBarVariant` are used identically across all tasks. `tapErrorActive` and `updateAvailable` are both declared `@Published private(set)` and mutated only via internal closures (`onTapError`/`onTapRecovered`) or the explicit `setUpdateAvailable(_:)` setter (the latter is the bridge used by `SparkleUpdateObserver`).
- **Incremental green:** Each task ends with a passing test suite. Tasks 7-9 use smoke gates (`testMenuBarIconView<Variant>Renders`) that pass even before the inner content is filled in — the actual visual gate is the manual smoke test in Task 11. This is intentional: pixel-level assertions are too fragile, and "doesn't crash" is a meaningful invariant for SwiftUI views.
- **No placeholders:** All code blocks contain complete, copy-pasteable code. No "implement appropriate error handling" / "TODO" / "similar to Task N" indirection.
