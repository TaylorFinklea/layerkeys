# Menu-bar icon redesign — design spec

**Date:** 2026-05-06
**Milestone:** M4b (UX polish — first iceberg below the M4a release-pipeline waterline)
**Status:** Approved through brainstorming; awaiting implementation plan.

## Context

LayerKeys ships today with a menu-bar item that pairs an SF Symbol
(`circle` / `arrow.up.left.and.arrow.down.right` / `number.square`) with
a hardcoded text label (`LK` / `NAV` / `NUM`). It works, but:

1. **No state distinction beyond mode.** Permission-denied falls back to
   `exclamationmark.triangle.fill`. Listen-only (Input Monitoring
   granted but Accessibility denied → tap-to-Escape silently broken) is
   indistinguishable from "all good" — a known M3 visibility gap.
2. **No update or tap-error visibility.** Sparkle is wired but the menu
   bar gives the user no signal that an update is waiting; tap recovery
   from sleep/wake is opaque.
3. **Generic identity.** SF Symbols make us look like every other menu
   bar utility. The product thesis ("layers stacked under your fingers")
   doesn't show up at the icon level.

This spec lands a single custom SwiftUI-rendered icon (`MenuBarIconView`)
that handles 7 distinct states and replaces the icon-plus-text pair
with a glyph-only treatment. The state plumbing also fixes the M3
listen-only visibility gap and exposes Sparkle update + tap-error
signals that today live only in the menu's `lastError` string.

## Visual concept (locked during brainstorming)

A keyboard keycap silhouette as the constant identity. The cap shell
(rounded rectangle with a horizontal shelf line) stays the same across
all states; only the inner content changes.

Common geometry, 24×24 viewBox:
- Cap shell: `rect x=3 y=5 w=18 h=14 rx=2.5`, stroke-width 2
- Shelf line: `y=11`, full width
- Lower face (where state content lives): roughly x=4..20, y=12..18

The 7 variants:

| # | Variant | Inner content | Accessibility label |
|---|---|---|---|
| 1 | Off | Single dim center dot at (12, 15), r=0.6, filled | "LayerKeys, idle" |
| 2 | Nav | 4-way directional cluster: vertical line (12,12.5)→(12,17.5), horizontal (9.5,15)→(14.5,15), four chevron tips | "LayerKeys, navigation layer active" |
| 3 | Numpad | 3×3 dot grid at columns x=8,12,16 × rows y=13,15,17, r=0.7 each, filled | "LayerKeys, numpad layer active" |
| 4 | Permission denied | Diagonal slash (5,6)→(19,18) at stroke-width 2.5; cap shell rendered orange | "LayerKeys, input monitoring permission denied" |
| 5 | Listen-only | Six explicit dash segments (no `stroke-dasharray`) at x=6–8, 11–13, 16–18 × y=14.5, 17 | "LayerKeys, listen-only mode — tap-to-Escape disabled" |
| 6 | Update available | Composes onto any non-error/non-denied base + corner badge: filled circle (20, 6) r=3 with white ↓ glyph inside | base label + ", update available" |
| 7 | Tap error | ✕ inside cap: two crossed lines (9,13.5)→(15,17.5) and (15,13.5)→(9,17.5) at stroke-width 2.2; cap shell rendered red | "LayerKeys, event tap error" |

All seven were validated visually during brainstorming via a
side-by-side mockup grid; revisions to nav, numpad, and listen-only
were applied to keep inner content cleanly inside the cap silhouette.

## Architecture

### Rendering strategy: SwiftUI `Path` / `Canvas`

`MenuBarIconView` is a SwiftUI `View` that draws the validated SVG
geometry as native `Path` definitions inside a `Canvas`. Color is
applied via `.foregroundStyle` rather than baked into the shape, which
lets us tint per state (orange for denied, red for error) without
maintaining color-baked image assets.

This was selected over (B) template-image PDFs in `Assets.xcassets`
and (C) a custom SF Symbol set because:

- Template images are single-color by definition; the orange-denied /
  red-error states would require non-template variants (losing macOS
  appearance integration) or per-state SwiftUI tint overrides on top
  of an already-color-baked asset.
- A custom SF Symbol set requires authoring in Apple's SF Symbols app
  and round-tripping `.svg` files in their exact layer-structure
  format. Heavyweight for 7 closely related glyphs.
- The validated SVG path strings translate one-to-one into Swift
  `Path` calls — single source of truth, easy to iterate on geometry
  later, no asset-pipeline overhead.

### Component structure

One new file at `LayerKeys/MenuBarIconView.swift`:

```swift
struct MenuBarIconView: View {
    enum Variant {
        case off, nav, numpad, denied, listenOnly, error
    }

    let variant: Variant
    let updateBadge: Bool

    var body: some View {
        Canvas { ctx, size in
            drawCapShell(in: ctx, size: size)
            drawInnerContent(in: ctx, size: size)
            if updateBadge { drawUpdateBadge(in: ctx, size: size) }
        }
        .frame(width: 18, height: 18)
        .foregroundStyle(variant.tint)
        .accessibilityLabel(variant.accessibilityLabel)
    }
}
```

Pure presentation. No `@MainActor`, no AppModel reference. The
translation from AppModel state → `Variant` happens at the call site.

### State source mapping

A pure resolution function determines which variant to show:

```swift
func resolve(mode: LayerMode,
             perm: InputMonitoringPermissionState,
             tapErrorActive: Bool,
             updateAvailable: Bool) -> (variant: MenuBarIconView.Variant,
                                        badge: Bool) {
    if tapErrorActive      { return (.error,      false) }
    if perm == .denied     { return (.denied,     false) }
    if perm == .listenOnly { return (.listenOnly, updateAvailable) }
    switch mode {
    case .off:    return (.off,    updateAvailable)
    case .nav:    return (.nav,    updateAvailable)
    case .numpad: return (.numpad, updateAvailable)
    }
}
```

Priority order: **error > denied > listen-only > mode**. Update badge
composes on listen-only / off / nav / numpad but never on error or
denied (those are already alert states; double-stacking alerts is
incoherent).

This function lives next to `MenuBarIconView` (or on AppModel as a
computed property — implementation choice for the plan). It is pure
and easy to unit-test exhaustively.

### Color treatment

| Variant | `foregroundStyle` |
|---|---|
| Off / Nav / Numpad / Listen-only | `.primary` (system tracks light/dark menu bar appearance) |
| Denied | `.orange` |
| Error | `.red` |

Update badge inherits the base variant's color — the corner ↓ glyph
itself is the affordance, not color.

SwiftUI's `MenuBarExtra` applies the standard pressed/highlight
treatment to its label automatically. Drawing with `.foregroundStyle`
(not hardcoded colors) inherits that for free.

### Drop the text label

The current `Image(systemName:) + Text(model.mode.menuBarLabel)` pair
becomes `MenuBarIconView` only. State-distinct icons make the text
redundant; a glyph-only menu bar item also matches how every other
macOS utility ships.

## New AppModel state

Two new `@Published` properties:

```swift
@Published private(set) var updateAvailable: Bool = false
@Published private(set) var tapErrorActive: Bool = false
```

Plus a derived computed property:

```swift
var menuBarVariant: (variant: MenuBarIconView.Variant, badge: Bool) {
    resolve(mode: mode,
            perm: permissionState,
            tapErrorActive: tapErrorActive,
            updateAvailable: updateAvailable)
}
```

### `updateAvailable` plumbing (Sparkle)

LayerKeysApp adds a small `SPUUpdaterDelegate` (a class, since the
protocol is `NSObjectProtocol`-rooted) that flips
`model.updateAvailable`:

- `updater(_:didFindValidUpdate:)` → `true`
- `updater(_:didDismissUpdateAlertPermanently:for:)` → `false`
- `updater(_:didFinishUpdateCycleFor:error:)` → `false` if
  `error != nil` (cycle aborted) or `error == nil` and no update was
  installed (user deferred). When an update *was* installed, the app
  has already relaunched, so this branch is unreachable.

The delegate is owned by LayerKeysApp alongside the existing
`SPUStandardUpdaterController` and bridges to AppModel via a closure.

### `tapErrorActive` plumbing (EventTapService)

EventTapService today exposes `onTapError: ((String) -> Void)?` —
fired both on initial tap death AND on sleep/wake recovery messages
(the "Restarting event tap after sleep recovery" string passes
through the same channel). This means we can't infer "tap is broken
right now" from `onTapError` alone.

Surface a complementary signal:

```swift
final class EventTapService {
    var onTapError: ((String) -> Void)?
    var onTapRecovered: (() -> Void)?  // NEW
    // ...
}
```

`onTapRecovered` fires when `start()` succeeds after a previous tap
death. AppModel sets `tapErrorActive = true` on `onTapError` and
`tapErrorActive = false` on `onTapRecovered`. The existing
`lastError` string state remains as-is for the menu's text display.

(Alternative considered: replace `onTapError`/`onTapRecovered` with
a single `@Published var tapHealth: TapHealth` enum on
EventTapService. Rejected for this milestone — wider blast radius
than necessary; the two-callback shape is the smallest change that
gets the job done.)

## File layout

| File | Change |
|---|---|
| `LayerKeys/MenuBarIconView.swift` *(new)* | The SwiftUI view + `Variant` enum + `Path` definitions for all 7 variants + `resolve(...)` pure function (or in AppModel — implementer's choice). |
| `LayerKeys/AppModel.swift` | Add `updateAvailable` + `tapErrorActive` `@Published` properties + `menuBarVariant` computed property. Wire `service.onTapRecovered = { ... tapErrorActive = false }` and update the existing `service.onTapError` closure to also set `tapErrorActive = true`. |
| `LayerKeys/LayerKeysApp.swift` | Replace the `Image(systemName:) + Text(...)` pair (line 27) with `MenuBarIconView(variant: model.menuBarVariant.variant, updateBadge: model.menuBarVariant.badge)`. Add a small `SparkleUpdateObserver` class conforming to `SPUUpdaterDelegate` and pass it to `SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: ..., userDriverDelegate: nil)`. |
| `LayerKeys/EventTapService.swift` | Add `onTapRecovered: (() -> Void)?`. Fire it on the recovery-success path inside `SleepWakeHandler.didWake` (after the `restartEngine()` succeeds). |
| `LayerKeys/KeyCatalog.swift` | The existing `LayerMode.menuBarLabel` and `LayerMode.symbolName` properties become unused after the icon swap. Delete them; nothing else references the old strings. |
| `LayerKeysTests/MenuBarIconViewTests.swift` *(new)* | Pure-function tests for `resolve(...)` + visual snapshot tests via `ImageRenderer`. |
| `LayerKeysTests/AppModelTests.swift` | Add tests for `updateAvailable` / `tapErrorActive` plumbing and `menuBarVariant` priority order. |

## Testing

**Pure-function tests (~10 cases)** for `resolve(...)`:

- `off` mode + granted + no error + no update → `.off`, badge=false
- `off` mode + granted + no error + update → `.off`, badge=true
- `off` mode + listenOnly + no error + no update → `.listenOnly`, badge=false
- `off` mode + listenOnly + no error + update → `.listenOnly`, badge=true
- `off` mode + denied + no error + no update → `.denied`, badge=false
- `off` mode + denied + no error + update → `.denied`, badge=false (priority overrides)
- `off` mode + granted + error + no update → `.error`, badge=false
- `off` mode + granted + error + update → `.error`, badge=false (priority overrides)
- `nav` mode + granted + no error + no update → `.nav`, badge=false
- `numpad` mode + granted + no error + update → `.numpad`, badge=true
- `nav` mode + denied + no error + no update → `.denied`, badge=false (denied wins over mode)

**Visual snapshot tests (~7 cases)** for `MenuBarIconView`:

- Render each variant via `ImageRenderer(content: MenuBarIconView(...))`
  at 18×18 to PNG.
- First run writes `LayerKeysTests/__Snapshots__/MenuBarIcon-<variant>.png`.
- Subsequent runs compare bytes; mismatch = test fail.
- Update flow: delete the PNG, re-run, eyeball the new file in
  Finder, commit if correct.

**AppModel plumbing tests:**

- `updateAvailable` flips when the Sparkle delegate's
  `didFindValidUpdate` is called.
- `tapErrorActive` flips when `service.onTapError` fires; clears when
  `service.onTapRecovered` fires.
- `menuBarVariant` returns the expected tuple under combinations of
  the four inputs.

**Manual smoke test (post-implementation):**

1. Launch app — observe `.off` icon (filled center dot).
2. Hold Control+Space — observe icon swap to `.nav` (4-way arrows).
3. Add the numpad sub-trigger — observe swap to `.numpad` (dot grid).
4. Revoke Input Monitoring in System Settings → observe `.denied`
   (orange diagonal slash).
5. Restore Input Monitoring; revoke Accessibility → observe
   `.listenOnly` (dashed lower face). This currently shows nothing
   distinct — the visibility fix.
6. Trigger a Sparkle check ("Check for Updates…" with a staging
   appcast) → observe corner ↓ badge composing onto the active
   variant.
7. Force tap death (sleep/wake while the tap is in a known-bad state,
   or kill the tap from a debugger) → observe `.error` (red ✕);
   observe it clears once the recovery path completes.

Full XCTest suite remains green: existing 51 + new ~17 = ~68 total.

## Verification

End-to-end success criteria:

```bash
xcodebuild test -scheme LayerKeys \
  -project LayerKeys.xcodeproj \
  -destination 'platform=macOS'
```

Expected: all tests pass, including the new snapshot tests.

Visual: open the app and step through the manual smoke test above.
Each of the 7 states should produce a distinct, on-brand glyph in the
menu bar, with no text label beside it.

## Out of scope

- **Animation between variants.** The icon snaps; no transition. Adding
  a `.transition` modifier is a follow-up if desired.
- **Custom badge for "settings open" / "menu open" states.** SwiftUI's
  built-in pressed-state treatment is sufficient.
- **App icon (`AppIcon.appiconset`) refresh.** That's the dock/Finder
  icon, not the menu bar; explicit M4b non-goal already.
- **Localized accessibility labels.** Strings stay en-US to match the
  rest of the app; localization is a separate later milestone.
- **Configurable color theming.** No user setting for "always use
  monochrome" — the orange/red are functional indicators, not
  decoration.
- **Drop-in compatibility with the old `LayerMode.symbolName` /
  `menuBarLabel` API.** Those properties are removed; nothing else
  in the codebase consumes them after this change.

## ADR notes (to append to `decisions.md`)

- **Custom SwiftUI keycap glyph over SF Symbols.** Generic SF Symbols
  collapsed onto each other at small sizes and gave us no path to
  state-specific tinting that didn't fight the system. A bespoke
  silhouette is the small amount of design work that buys
  ever-distinguishable state visualization.
- **`Path`/`Canvas` rendering over template-image PDFs.** Single
  source of truth (the validated SVG paths translate directly to
  Swift). Per-variant tinting via `.foregroundStyle` instead of color
  baked into asset variants. Trade-off accepted: we lose the
  automatic system tinting that template images get, but we don't
  want it for the orange/red states anyway.
- **Drop the text label beside the icon.** State-distinct iconography
  makes the "LK"/"NAV"/"NUM" text redundant; glyph-only matches
  conventional macOS menu-bar utility behavior.
- **`error > denied > listen-only > mode` priority order.** Errors
  and permissions are blocking — they should preempt the mode
  display. Listen-only is a partial-failure mode where the layers
  still work; show the listen-only marker but allow the mode signal
  to be inferred from interaction (the user knows whether they're
  holding the trigger).
- **Update badge composes on non-alert variants only.** Stacking
  "update available" on top of "tap error" is incoherent — fix the
  error first.
