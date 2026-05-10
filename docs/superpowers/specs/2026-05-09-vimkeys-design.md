# VimKeys — design specification

- **Status**: Approved for implementation
- **Date**: 2026-05-09
- **Owner**: Taylor Finklea
- **Implementation target**: Codex (Codex Cloud or Codex CLI on macOS)
- **Sibling-of**: [LayerKeys](https://github.com/TaylorFinklea/layerkeys)
- **Decision context**: see `docs/decisions/safari-vim-nav.md` in the LayerKeys repo

## TL;DR for the implementer

Build **VimKeys**, a notarized macOS menu-bar app that gives Safari
vim-style home-row navigation. Single-target Swift 6 / macOS 14+ app,
forked from LayerKeys' architecture (`CGEventTap` engine on a dedicated
thread, pure value-type state machine, SwiftUI menu-bar shell). Adds
on top: AX observers for Safari, AX traversal for link hints, an
AppleScript bridge for URL/bookmark/tab data, three overlay windows
(hint / vomnibar / help), per-domain blocklist, three-permission
onboarding, signed/notarized release pipeline mirroring LayerKeys M4a.

Repo: `TaylorFinklea/vimkeys` (new). Bundle ID:
`io.taylorfinklea.vimkeys`. License MIT. Distribution via Homebrew
cask. No analytics, no telemetry. Six PRs from empty repo to 1.0.0
release.

## Product positioning

"Vim-style home-row navigation in Safari, done right." Same minimalist
ethos as LayerKeys: one job, no leader-key sprawl, no generalized
"any web view, any app" mode. Compares against:

- **Vimari** (Safari Web Extension) — unmaintained since 2020. Sandboxed.
- **Vifari** (Hammerspoon Spoon) — works, but Hammerspoon's auto-execute
  Lua posture won't clear MDM/HIPAA security review.
- **Vimium** (Chrome extension) — gold-standard reference for behavior;
  Safari-equivalent doesn't exist.

VimKeys' niche: **a notarized native Mac binary that delivers
Vimium-class behavior on Safari, and is plausibly approvable on a
managed/HIPAA-compliant Mac**. Same architectural posture as LayerKeys
(narrowly scoped, fully offline, MIT, Developer-ID signed and Apple-
notarized) plus one new capability — AX traversal of Safari's
`AXWebArea` for link hints, used on-demand rather than continuously.

## Capability target

Vim-style Safari navigation on macOS. **Always on when Safari is
frontmost; AX-aware so it gets out of the way in text inputs.**

### Bindings (full v1.0 set)

| Key | Command | Behavior |
|-----|---------|----------|
| `j` / `k` | scroll down / up | 3 lines × repeat count |
| `h` / `l` | scroll left / right | 3 lines × repeat count |
| `d` / `u` | half-page down / up | viewport / 2 × repeat count |
| `gg` | top of page | scroll to top |
| `G` | bottom of page | scroll to bottom |
| `f` | link hint | overlay labels; type to click |
| `F` | link hint, new tab | hint dispatch with Cmd-modifier |
| `gi` | focus first input | hint-traversal filtered to text inputs, auto-click first |
| `gs` | view source | AppleScript bridge |
| `/` | find in page | synthesize Cmd+F (Safari's native find) |
| `n` / `N` | find next / previous | Cmd+G / Cmd+Shift+G |
| `H` / `L` | history back / forward | Cmd+[ / Cmd+] |
| `r` / `R` | reload / hard reload | Cmd+R / Cmd+Shift+R |
| `yy` | copy URL | bridge.currentURL → clipboard |
| `yf` | copy link URL | hint dispatch + clipboard |
| `o` / `O` | URL/history vomnibar (current/new tab) | overlay; Apple Events to Safari |
| `b` / `B` | bookmark vomnibar (current/new tab) | overlay; Apple Events |
| `T` | open-tab search vomnibar | overlay; Apple Events |
| `p` / `P` | open clipboard URL (current/new tab) | parse clipboard, navigate |
| `i` | enter insert mode | manual override |
| `Esc` | exit insert / cancel prefix / dismiss overlay | context-dependent |
| `?` | help overlay | shows binding reference |
| digits | repeat count | `5j` scrolls 5×; cap 999 |
| `Esc Esc` | suspend until reload | session-scoped |

**Tab switching** (`J`/`K` in Vimium) is intentionally **not** included —
already handled by macOS App Shortcuts binding `Cmd+H`/`Cmd+L` to
Safari's "Show Next Tab"/"Show Previous Tab" menu items.

**No user-customizable bindings at v1.0.** Bindings tab in Settings is
read-only. Customization is a v1.x feature, gated on real demand.

## Architectural shape

Approach 1 from brainstorming: LayerKeys-shaped, ship-first. Single
executable target. Files mirror LayerKeys' style. AX wrapped in a
`SafariObserver` service that emits events to `AppModel`/state machine.
Fork LayerKeys files into the new repo as a starting point and modify
in place. **Do not extract a shared `KeyTapKit` SPM package at v1.0** —
revisit after VimKeys 1.0 ships and divergence is real.

## Top-level file layout

```
vimkeys/                              -- repo root
  project.yml                         -- XcodeGen config
  README.md
  LICENSE                             -- MIT
  AGENTS.md                           -- adapted from LayerKeys
  .github/
    workflows/
      ci.yml                          -- xcodebuild test on PRs
      release.yml                     -- sign + notarize + upload on tag
  scripts/
    package_release.sh                -- forked from LayerKeys
    update_homebrew_tap.sh            -- forked from LayerKeys
  docs/
    decisions/                        -- ADRs as they accumulate
    manual-tests/v1.0-smoke.md
  VimKeys/
    VimKeysApp.swift                  -- @main, app shell, settings scene wiring
    AppModel.swift                    -- @MainActor ObservableObject, top-level state
    EventTapEngine.swift              -- forked from LayerKeys, lightly adapted
    EventTapService.swift             -- forked from LayerKeys, lightly adapted
    PermissionController.swift        -- forked + extended (AX trust + Apple Events)
    LaunchAtLoginController.swift     -- forked unchanged
    SparkleUpdateObserver.swift       -- forked unchanged
    MenuBarIconView.swift             -- forked, re-themed
    StatusMenuView.swift              -- forked, restructured
    SafariObserver.swift              -- NEW: AX + NSWorkspace observers
    SafariBridge.swift                -- NEW: AppleScript wrapper
    LinkHintEngine.swift              -- NEW: AX traversal + label algorithm
    VimStateMachine.swift             -- NEW: pure state machine
    KeyCatalog.swift                  -- NEW: VimCommand + default bindings
    OverlayManager.swift              -- NEW: coordinates 3 overlay windows
    Overlays/
      HintOverlayWindow.swift
      VomnibarWindow.swift
      HelpOverlayWindow.swift
    Settings/
      SettingsView.swift
      GeneralTab.swift
      BindingsTab.swift
      SitesTab.swift
      AboutTab.swift
    Persistence/
      SettingsStore.swift
      SitesStore.swift
    Onboarding/
      OnboardingWindow.swift
    TabSuspendTracker.swift
    Assets.xcassets/
    Info.plist
  VimKeysTests/
    VimStateMachineTests.swift
    KeyCatalogTests.swift
    LinkHintLabelAlgorithmTests.swift
    SitesStoreTests.swift
    SettingsStoreTests.swift
    SafariBridgeMockTests.swift
```

## State machine model

The heart of the app. Pure value type, mirrors LayerKeys'
`LayerStateMachine` shape: events in, decisions out, side effects
executed by the engine.

### Mode enum

```swift
enum VimMode: Equatable {
    case disabled                       // Safari not frontmost OR domain blocked OR suspended
    case insert                         // Focus in editable element OR user pressed `i`
    case normal(prefix: CommandPrefix)  // Vim keys live, possibly with pending command/count
    case find(buffer: String)           // (reserved — currently `/` synthesizes Cmd+F so unused at v1)
    case hint(HintState)                // `f` / `F` is open
    case vomnibar(VomnibarState)        // `o`/`O`/`b`/`B`/`T` is open
}

enum CommandPrefix: Equatable {
    case none
    case count(Int)        // "5", "12" — buffered before a motion
    case g(count: Int?)    // `g` pressed, awaiting gg/gi/gs/gf
    case y(count: Int?)    // `y` pressed, awaiting yy/yf
}

struct HintState: Equatable {
    enum Phase: Equatable {
        case collecting(openInNewTab: Bool, copyOnly: Bool)  // awaiting AX traversal
        case awaiting(labels: [Hint], openInNewTab: Bool, copyOnly: Bool)
        case dispatching(target: Hint)
    }
    var phase: Phase
    var typedBuffer: String      // letters typed so far (matched against labels)
    var filterText: String       // separate buffer for filter-by-text mode
}

struct VomnibarState: Equatable {
    enum Kind: Equatable { case url, bookmarks, tabs }
    var kind: Kind
    var openInNewTab: Bool
    var query: String
    var results: [VomnibarResult]
    var selectedIndex: Int
}
```

### Engine-executed intents

```swift
enum VimIntent: Equatable {
    case passThrough
    case consume
    case scroll(direction: ScrollDirection, amount: ScrollAmount)
    case scrollToEdge(VerticalEdge)
    case postKey(virtualKey: CGKeyCode, flags: CGEventFlags)
    case showOverlay(OverlayKind)
    case updateOverlay(OverlayUpdate)
    case dismissOverlay
    case requestHintTraversal(openInNewTab: Bool, copyOnly: Bool, filter: HintFilter)
    case dispatchHintClick(at: CGPoint, modifierFlags: CGEventFlags)
    case requestSafariURL
    case requestBookmarks
    case requestOpenTabs
    case openURL(String, inNewTab: Bool)
    case copyToClipboard(String)
    case unfocusActiveElement
    case toggleSuspended
    case showHelp
}

enum ScrollDirection { case vertical, horizontal }

enum ScrollAmount: Equatable {
    case lines(Int)        // signed
    case halfPage(Int)     // signed; multiplied by viewport/2 at execute time
}

enum VerticalEdge { case top, bottom }

enum OverlayKind { case hints([Hint]), vomnibar(VomnibarState), help }

enum OverlayUpdate {
    case hintInput(buffer: String)
    case vomnibarQuery(String)
    case vomnibarSelectionDelta(Int)
}

enum HintFilter { case anyClickable, textInputsOnly }
```

### Decision shape

```swift
struct VimDecision: Equatable {
    let intent: VimIntent
    let modeDidChange: Bool
    let newMode: VimMode?
}

struct VimStateMachine {
    private(set) var mode: VimMode = .disabled
    var settings: VimSettings   // hint alphabet, insertModeBehavior, etc.

    mutating func decide(
        eventType: CGEventType,
        keyCode: CGKeyCode,
        characters: String?,        // resolved via NSEvent(cgEvent:)?.charactersIgnoringModifiers
        flags: CGEventFlags,
        timestamp: UInt64
    ) -> VimDecision

    // External event sources (called by AppModel from observer callbacks):
    mutating func updateSafariFrontmost(_ isFrontmost: Bool) -> VimDecision?
    mutating func updateFocusEditable(_ isEditable: Bool) -> VimDecision?
    mutating func updateCurrentDomain(_ host: String?, fullURL: URL?) -> VimDecision?
    mutating func updateBlockedDomains(_ blocked: Bool)
    mutating func updateOverlayResult(_ result: OverlayResult) -> VimDecision?

    // Timeout for pending prefix (g/y/count):
    mutating func commandTimeout() -> VimDecision
}
```

### Why `characters` not just keycode

Vim bindings are character-based (`f`, `g`, `?`, `/`), not keycode-based.
The engine resolves once per event using `NSEvent(cgEvent:)?.charactersIgnoringModifiers`.
This handles non-US layouts correctly (a French AZERTY user pressing
the key labeled `?` produces the right `?` character).

### Mode transitions (the high-stakes ones)

| Trigger | From | To | Notes |
|---|---|---|---|
| Safari frontmost | `.disabled` | `.normal(.none)` or `.insert` | Set by `SafariObserver` |
| Safari not frontmost | any | `.disabled` | Dismiss overlays; reset prefix |
| Domain enters blocklist | `.normal`/`.insert` | `.disabled` | URL change OR settings change |
| Focus → editable | `.normal` | `.insert` | AX `AXFocusedUIElementChanged` |
| Focus → non-editable | `.insert` | `.normal(.none)` | AX |
| User presses `i` | `.normal(.none)` | `.insert` | Manual override |
| `Esc` in `.insert` | `.insert` | `.normal(.none)` + `.unfocusActiveElement` | Posts Esc to Safari |
| `Esc` in `.normal(prefix)` | `.normal(prefix)` | `.normal(.none)` | Cancel pending |
| `Esc` in overlay | overlay | `.normal(.none)` + `.dismissOverlay` | |
| Digit in `.normal(.none)` | `.normal(.none)` | `.normal(.count(n))` | `0` is count digit only if existing count |
| Digit in `.normal(.count(n))` | | `.normal(.count(n*10 + d))` | Cap at 999 |
| `f` / `F` | `.normal(prefix)` | `.hint(.collecting)` + `.requestHintTraversal` | |
| `gi` | `.normal(.g)` | `.hint(.collecting(filter: .textInputsOnly))` | |
| Hint traversal returns | `.hint(.collecting)` | `.hint(.awaiting(labels))` + `.showOverlay` | |
| Char during hint | `.hint(.awaiting)` | filter; if exactly 1 → dispatch | |
| `Esc Esc` (within 300 ms, no other key between) | `.normal(.none)` | `.disabled` (suspended) + `.toggleSuspended` | Any non-Esc key in between resets the chord buffer |

### Command-prefix timeout

`g`, `y`, and pending counts time out to `.normal(.none)` after **1500 ms**
of no follow-up. Engine schedules a one-shot timer; on fire, calls
`commandTimeout()`. Matches Vimium.

### Repeat-count cap

999. Prevents `999999999999j` posting a billion scroll events. Unlikely
to bite a real user.

## AX strategy + Safari bridge

### `SafariObserver`

**Responsibility**: watch the system, emit four event types. Never
blocks the event tap thread.

**Event sources**:

| Event | API |
|---|---|
| Safari frontmost changed | `NSWorkspace.shared.notificationCenter` `didActivateApplicationNotification` |
| Safari focus changed | `kAXFocusedUIElementChangedNotification` on Safari's `AXApplication` |
| Current Safari tab URL changed | `kAXValueChangedNotification` on Safari's address-bar `AXTextField` |
| Tab/window changed | `kAXFocusedWindowChangedNotification` on Safari's `AXApplication` |

**Lifecycle**:

- Starts when both Input Monitoring and Accessibility are granted.
- On Safari frontmost: discover Safari's PID via `NSRunningApplication`,
  create `AXUIElementCreateApplication(pid)`, attach `AXObserver`,
  subscribe to four notifications.
- On Safari quit / not-frontmost: tear down observer.
- Re-attach if Safari relaunches (`didLaunchApplicationNotification`).

**Bundle IDs treated as Safari**: `com.apple.Safari` and
`com.apple.SafariTechnologyPreview`. Anything else → `.disabled`.

**Focus-editable check**: when focus changes, read focused element's
`kAXRoleAttribute` + `kAXSubroleAttribute`. Mode = `.insert` if role is
one of `AXTextField`, `AXTextArea`, `AXComboBox`, or has `AXEditable`
attribute true, or `AXSubrole == AXSecureTextField`, or
`AXRoleDescriptionAttribute` contains "text".

**URL-change handling**: address-bar `AXValueChanged` → parse host →
`SitesStore.matches(...)` → push mode update. Debounce 200 ms (SPAs
fire many).

**Threading**: runs on `MainActor`. AX callbacks land on the run loop
the observer was created on (main). Pushes mode updates into `AppModel`.

### `SafariBridge`

**Responsibility**: AppleScript wrapper for what AX can't do
efficiently. Async, serialized on a private actor.

```swift
actor SafariBridge {
    func currentURL() async throws -> URL?
    func currentTitle() async throws -> String?
    func openURL(_ url: URL, inNewTab: Bool) async throws
    func reload(hard: Bool) async throws
    func bookmarks() async throws -> [BookmarkEntry]
    func openTabs() async throws -> [TabEntry]
    func historyItems(matching query: String, limit: Int) async throws -> [HistoryEntry]
    func viewSource() async throws
}
```

**Implementation**: pre-compiled `OSAScript` (`OSAKit`) per template; ~5x
faster than re-compiling each call. Parameters passed via OSA, not
string interpolation.

**Caching**:
- Bookmarks: 60-second TTL; vomnibar can force refresh.
- History: 5-minute TTL.
- Open tabs: never cached.

**Errors**: every method throws. Consumers display non-blocking error
in overlay (red toast) or set menu-bar variant to error state.

**First-launch Apple Events permission**: on first call, macOS shows
TCC prompt "VimKeys would like to control Safari." Onboarding warns
the user this prompt is coming.

### `LinkHintEngine`

**Responsibility**: walk Safari's `AXWebArea` subtree on demand, find
clickable elements in the viewport, return `[Hint]`. Background queue.
Never on event-tap thread.

**Algorithm**:

1. Get Safari's focused window via `kAXFocusedWindowAttribute`.
2. Find `AXWebArea` descendant via DFS, capped 20 levels.
3. From `AXWebArea`, enumerate descendants matching:
   - Roles: `AXLink`, `AXButton`, `AXCheckBox`, `AXRadioButton`, `AXPopUpButton`
   - Or `AXTextField` / `AXTextArea` (so `f` works to focus inputs too)
   - Or any element with non-nil `AXURL`
4. For each, fetch `AXFrame` (CGRect, screen coords) and `AXTitle` /
   `AXDescription` / `AXValue` for filter-by-text.
5. Filter to elements intersecting Safari's viewport rect.
6. Return ordered list (top-to-bottom, left-to-right within row tolerance 20 px).

**Performance budget**: 200 ms wall-clock from `f` press to overlay
rendered, on a 500-candidate page. Beyond, show "scanning…" indicator.

**Label algorithm** (Vimium-default-style, pure function in
`LinkHintLabelAlgorithm.swift`):

```swift
func labels(for count: Int, alphabet: String) -> [String]
```

- Compute minimum length L such that `alphabet.count^L >= count`.
- Generate labels by treating index 0..<count in base `alphabet.count`,
  padding to L with the first character.
- Most-frequent positions get shortest labels.
- Default alphabet: `sadfjklewcmpgh` (no `i` because that's insert mode).
- All labels uppercased in overlay.

**Filter-by-text**: as user types each character, simultaneously match:
- Label prefix (`"sa"` matches label `"SADF"`)
- Substring of element's accessible text (case-insensitive)

If exactly one candidate remains → emit `.dispatchHintClick`.

**Click dispatch**: post synthesized `CGEvent` `mouseDown` + `mouseUp`
at candidate's `AXFrame` center. With `Cmd` flag if `openInNewTab`.
Cursor visibly jumps; matches Vifari behavior.

Alternative considered: AX `AXPress` action — rejected because it
doesn't carry modifier flags (no Cmd-click for new tab) and doesn't
handle text-field focus.

## Overlay UIs

Three `NSPanel` subclasses, non-activating, transparent, each hosting
SwiftUI content. None steal focus from Safari. None capture keyboard
directly — keystrokes flow tap → state machine, which pushes
`.updateOverlay` intents to `OverlayManager`.

`/` (find) does **not** need an overlay — it just synthesizes `Cmd+F`
and Safari's native find bar opens. `n`/`N` synthesize `Cmd+G`/`Cmd+Shift+G`.

### `HintOverlayWindow`

```swift
class HintOverlayWindow: NSPanel {
    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}
```

**Sizing**: window frame = Safari focused window's `AXFrame` (in screen
coords, after Y-flipping AX coords to AppKit coords).

**Label rendering**: SwiftUI `HintLabel` view. Yellow background, black
1pt border, 12pt bold monospaced text. Dimmed prefix as user types,
active suffix in black.

**Updates**: state machine emits `.updateOverlay(.hintInput(buffer:))`;
`OverlayManager` re-renders.

**Auto-click**: when filtered list reaches 1, state machine emits
`.dispatchHintClick(at:modifierFlags:)` + `.dismissOverlay`.

**Cancellation**: Esc → dismiss. Also Safari loses frontmost.

**Multi-window**: only focused Safari window gets hints.

### `VomnibarWindow`

**Position**: centered on the screen containing Safari's focused window.

**Size**: 600 pt × max 400 pt tall (resizes to fit results, capped).

**Layout** (SwiftUI):

```
┌──────────────────────────────────────────────┐
│  [icon]  query as user types it              │
├──────────────────────────────────────────────┤
│  > Result 1 title                            │
│    https://result-1-url                      │
│    Result 2 title                            │
│    https://result-2-url                      │
│  ...                                         │
└──────────────────────────────────────────────┘
```

Header icon is an SF Symbol per kind: `link` for URL, `star.fill` for
bookmarks, `square.on.square` for tabs.

**Search algorithm**:

- URL flavor (`o`/`O`): history + bookmarks + open tabs, deduplicated by URL
- Bookmarks (`b`/`B`): bookmarks only
- Tabs (`T`): open tabs only

Matching: case-insensitive substring on title and URL. Sort:
1. Exact title prefix match
2. Title contains all query words
3. URL contains query

Limit 8 results.

**Navigation keys** (handled by state machine while in `.vomnibar` mode):
- character → append to query → re-filter
- Backspace → remove last character
- Down arrow / `Ctrl+J` → next result
- Up arrow / `Ctrl+K` → previous result
- Enter → open selected result via `.openURL(...)`, `inNewTab` per chord
- Esc → dismiss

**Empty state**:
- URL flavor (`o`/`O`): if no results, allow Enter to attempt query as raw URL (if it parses), otherwise Google search: `https://www.google.com/search?q=<urlencoded query>`.
- Bookmarks (`b`/`B`) and Tabs (`T`): if no results, Enter is a no-op. No fallback search — those bindings exist to find existing bookmarks/tabs, not to create new navigations.

### `HelpOverlayWindow`

**Triggered by**: `?`. Centered, 700×500 pt, scrollable. Three columns
(key chord, command name, description). Grouped by category.

**Dismiss**: Esc, `?` again, or any other key (first key dismisses help
and is not re-dispatched).

### `OverlayManager`

```swift
@MainActor
final class OverlayManager {
    private var hintWindow: HintOverlayWindow?
    private var vomnibarWindow: VomnibarWindow?
    private var helpWindow: HelpOverlayWindow?

    func handle(_ intent: VimIntent) { ... }
}
```

`AppModel` owns one. State-machine intents that touch overlays route through it.

## Settings UI + persistence

### Tabs

Four tabs in the `Settings` scene.

**General**:
- Launch at login toggle
- Check for updates automatically toggle
- Check for updates now button (Sparkle)
- Show menu-bar mode indicator toggle (default on)
- Insert-mode behavior segmented control: `Auto-detect via Accessibility` (default — focus changes auto-flip mode) / `Manual only (i to enter)` (focus changes ignored; user explicitly enters insert mode with `i`, exits with `Esc`)
- Hint label alphabet text field (default `sadfjklewcmpgh`)

**Bindings**:
- Read-only reference card
- Same content as help overlay
- Footer: "Custom bindings are not supported in v1."

**Sites** (per-domain disable):
- Header: "Don't intercept VimKeys on these sites."
- Table with columns: pattern, enabled toggle, delete button
- Below: text field + Add button. Validation as user types.
- Pattern types (auto-detected from input):
  - Exact host: `gmail.com`
  - Subdomain wildcard: `*.google.com` (subdomains only)
  - Both: `**.google.com` (host + subdomains)
  - URL prefix: `https://github.com/owner/repo`

**About**:
- App icon, name, version
- Tagline
- Links: GitHub, License (MIT), Privacy
- Acknowledgements: Vimium, Vifari
- Build info: commit SHA + build date

### Status menu (`MenuBarExtra` dropdown)

```
VimKeys — Normal
─────────────
Disable on this site            ← only enabled in Safari with known host
Suspend until reload
─────────────
Settings…                  ⌘,
Check for Updates…
About VimKeys
─────────────
Quit                       ⌘Q
```

Mode label color follows menu-bar icon variant.

### Persistence

Two stores, both UserDefaults-backed.

**`SettingsStore`**:

```swift
@MainActor
final class SettingsStore: ObservableObject {
    @Published var launchAtLoginEnabled: Bool
    @Published var insertModeBehavior: InsertModeBehavior
    @Published var hintAlphabet: String
    @Published var showMenuBarIcon: Bool
    @Published var checkForUpdatesAutomatically: Bool

    func save()
    func load()
}

enum InsertModeBehavior: String, Codable { case autoDetect, manual }
```

UserDefaults keys prefixed `settings.`.

**`SitesStore`**:

```swift
@MainActor
final class SitesStore: ObservableObject {
    @Published private(set) var entries: [SiteEntry] = []

    func add(_ pattern: String) throws -> SiteEntry
    func remove(_ id: UUID)
    func toggle(_ id: UUID)
    func matches(host: String, fullURL: URL?) -> Bool
}

struct SiteEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var pattern: String
    var kind: SitePatternKind
    var enabled: Bool
}

enum SitePatternKind: Codable, Hashable {
    case exactHost(String)
    case subdomainWildcard(String)
    case anyDomainWildcard(String)
    case urlPrefix(URL)
}

enum SitePatternError: Error {
    case empty
    case invalidHost(String)
    case invalidURL(String)
    case duplicate(SiteEntry)
}
```

**Pattern parser**:

1. Trim whitespace
2. Starts with `http://` or `https://` → parse URL → `.urlPrefix`
3. Starts with `**.` → strip prefix → `.anyDomainWildcard`
4. Starts with `*.` → strip prefix → `.subdomainWildcard`
5. Else: validate as hostname (RFC-952-ish: letters/digits/dots/hyphens, no scheme, no path) → `.exactHost`

**Match function**:

```swift
func matches(host: String, fullURL: URL?) -> Bool {
    let host = host.lowercased()
    return entries.filter(\.enabled).contains { entry in
        switch entry.kind {
        case .exactHost(let h):
            return host == h.lowercased()
        case .subdomainWildcard(let h):
            return host.hasSuffix(".\(h.lowercased())")
        case .anyDomainWildcard(let h):
            let base = h.lowercased()
            return host == base || host.hasSuffix(".\(base)")
        case .urlPrefix(let prefix):
            guard let url = fullURL else { return false }
            return url.absoluteString.lowercased()
                .hasPrefix(prefix.absoluteString.lowercased())
        }
    }
}
```

### Wiring

`AppModel` owns `SettingsStore` and `SitesStore`. Both publish via
`@Published`; SwiftUI views update reactively. On `SitesStore` change,
`AppModel.refreshBlockedDomains()` re-evaluates current host and pushes
mode update to state machine.

### `TabSuspendTracker` ("suspend until reload")

In-memory only, not persisted.

```swift
@MainActor
final class TabSuspendTracker {
    private var suspended: Set<String> = []   // keyed by "host + path"

    func suspend(host: String, path: String)
    func isSuspended(host: String, path: String) -> Bool
    func clearOnReload(host: String, path: String)
}
```

Reload detection: `kAXValueChangedNotification` on URL field where new
URL == previous URL → `clearOnReload`. Imperfect (also fires on hash
nav); acceptable.

User invokes via menu-bar dropdown OR `Esc Esc` chord (two Esc presses
within 300 ms while in `.normal(.none)`).

## Permissions + onboarding

### Three permissions

| # | Permission | Purpose | API check | Failure mode |
|---|---|---|---|---|
| 1 | Input Monitoring | Intercept keys globally | `CGPreflightListenEventAccess()` | Hard fail — app can't function |
| 2 | Accessibility | Read AX tree, post events, post mouse clicks for hint dispatch | `AXIsProcessTrustedWithOptions` + `CGPreflightPostEventAccess()` | Hard fail — link hints / AX-aware insert mode / URL detection break |
| 3 | Apple Events → Safari | URL, bookmarks, history, tabs; open URLs | First Apple Event to Safari → TCC prompt | Soft fail — vomnibar / yy / per-domain disable break, core scroll/find still works |

### Onboarding window

First launch and re-shown on launch if any **required** permission is
missing. Suppressed via `didCompleteOnboarding` UserDefaults flag once
user clicked Continue at least once.

```
┌──────────────────────────────────────────────────┐
│  Welcome to VimKeys                              │
│                                                  │
│  Vim-style navigation in Safari.                 │
│                                                  │
│  Three permissions are needed:                   │
│                                                  │
│  [✓] Input Monitoring          [Grant…]          │
│  [ ] Accessibility             [Grant…]          │
│  [ ] Apple Events → Safari     [Grant…]          │
│                                                  │
│  Each opens System Settings. After granting,     │
│  return here — VimKeys will detect it.           │
│                                                  │
│  [Skip for now]            [Continue ▸]          │
└──────────────────────────────────────────────────┘
```

- "Grant…" buttons call appropriate API: `CGRequestListenEventAccess`,
  `CGRequestPostEventAccess`, or send a no-op AppleScript to Safari to
  trigger the Apple Events prompt.
- Each row's checkbox auto-flips when polling detects grant (poll every
  2 s while window is open).
- "Continue" only enables when all three granted.
- "Skip for now" allowed; app shows degraded-mode warnings via menu-bar
  icon variant.

## Menu-bar icon variants

Reuse LayerKeys' `MenuBarIconView` rendering pattern + pure
`resolveMenuBarVariant(...)` resolver. Variants:

| Variant | When | Visual |
|---|---|---|
| off | Safari not frontmost | Dimmed glyph |
| normal | Safari frontmost, vim mode active | Default glyph |
| insert | Safari frontmost, focus in editable | Glyph + "I" badge |
| disabled | Site in blocklist | Glyph with strikethrough |
| suspended | "Until reload" suspend active | Glyph + pause badge |
| denied | Required permission missing | Orange glyph |
| listenOnly | Input Monitoring only, no Accessibility | Yellow glyph |
| tapError | Event tap died | Red glyph |
| updateAvailable | Sparkle has update | Glyph + up-arrow badge |

Glyph: stylized lowercase "v" inside a keycap silhouette. Same visual
family as LayerKeys, distinct.

## Distribution

Mirrors LayerKeys M4a end-to-end.

- **Build**: XcodeGen from `project.yml`. Sparkle 2.x SPM dep.
- **Sign**: `codesign --options runtime --timestamp --deep --sign "Developer ID Application: <name> (K7CBQW6MPG)"` — same Developer ID team as LayerKeys.
- **Notarize**: `xcrun notarytool submit --wait` using new keychain profile `vimkeys-notarytool` (user provisions once).
- **Sparkle**: NEW EdDSA keypair (do NOT reuse LayerKeys'). Public key in `Info.plist` `SUPublicEDKey`. Private key in user's macOS keychain; CI uses `SPARKLE_EDDSA_PRIVATE_KEY` GitHub secret. Appcast: `https://github.com/TaylorFinklea/vimkeys/releases/latest/download/appcast.xml`.
- **Scripts** (forked from LayerKeys): `scripts/package_release.sh`, `scripts/update_homebrew_tap.sh`.
- **GitHub Actions**: `.github/workflows/ci.yml` runs `xcodebuild test` on PRs and pushes to main; `.github/workflows/release.yml` on `v*` tag signs/notarizes and uploads `VimKeys.zip` + `appcast.xml`.

**Required GitHub secrets** (user provisions once):
- `APPLE_DEVID_CERT_P12_BASE64` (reuse from LayerKeys)
- `APPLE_DEVID_CERT_PASSWORD`
- `NOTARY_APPLE_ID`
- `NOTARY_PASSWORD`
- `NOTARY_TEAM_ID=K7CBQW6MPG`
- `SPARKLE_EDDSA_PRIVATE_KEY` (new, VimKeys-specific)

**Homebrew cask**: `../homebrew-tap/Casks/vimkeys.rb`. Same shape as
`layerkeys.rb`. URL: `https://github.com/TaylorFinklea/vimkeys/releases/download/v<version>/VimKeys.zip`.

## Privacy posture

Identical to LayerKeys, made explicit in Settings → About:
- No analytics, no crash reporting, no telemetry of any kind.
- Only network call: Sparkle appcast fetch.
- AX-derived data (link URLs, page titles, bookmarks) never leaves the process.
- Clipboard content never persisted.

This is load-bearing for the MDM/HIPAA hypothesis the project is built
around.

## Testing strategy

### Unit-testable (`VimKeysTests/`, XCTest, on every PR)

- `VimStateMachine` — full coverage of `decide`, all mode transitions,
  command-prefix logic, repeat counts, timeout behavior. Same pattern
  as LayerKeys' `testDecide*` suite. Target ≥90% line coverage.
- `KeyCatalog` — character-to-command resolution, default-bindings
  table integrity (no duplicates, every key maps to a command).
- `LinkHintLabelAlgorithm` — pure `labels(for:alphabet:) -> [String]`.
  Test minimum-length computation, sort order, alphabet edge cases
  (single char, very large counts).
- `SitesStore` — pattern parsing for all 4 kinds, match function
  exhaustively (exact / subdomain / any-domain / URL prefix), JSON
  round-trip.
- `SettingsStore` — load/save round-trip, defaults applied when keys
  missing, observable-published changes propagate.
- `SafariBridge` via `SafariBridgeProtocol` mock — tests can inject a
  fake returning canned URLs/bookmarks. Real bridge calls AppleScript
  and is integration-tested by hand.

### Manual-test-only

- AX traversal of Safari (real Safari window with real content)
- Hint overlay rendering (visual)
- AppleScript bridge against real Safari
- Permission grant flow (TCC prompts can't be scripted)
- Sparkle update flow

Manual smoke-test checklist at `docs/manual-tests/v1.0-smoke.md`. Codex
updates as features land.

## Milestone sequencing for Codex

Six PRs. Each is shippable on its own (passes `xcodebuild test`,
builds, runs).

### V-M1: Foundation + scroll (PR #1, → 0.1.0)

- Repo scaffolding: `project.yml`, `Info.plist`, `VimKeysApp.swift`
- Forked engine files: `EventTapEngine`, `EventTapService`,
  `PermissionController` (extend with Apple Events check + AX trust),
  `LaunchAtLoginController`, `SparkleUpdateObserver`,
  `MenuBarIconView` (re-themed)
- `KeyCatalog` with `VimCommand` enum + scroll/edge bindings only
- `VimStateMachine` with `.disabled`, `.normal(.none)`, `.normal(.count(n))` modes
- `SafariObserver` minimal: NSWorkspace frontmost only (AX deferred to V-M2)
- Bindings: `j k h l d u gg G` + repeat counts
- Status menu basics (Settings, About, Quit)
- Tests: state machine for above, KeyCatalog integrity
- README v1 with install/build/permissions

### V-M2: Insert mode + find + key-passthrough bindings (PR #2, → 0.2.0)

- Add AX observers for focus changes
- `.insert` mode + transitions
- Bindings: `/` `n` `N` `H` `L` `r` `R` `i` `Esc` `?`
- `HelpOverlayWindow` for `?`
- `InsertModeBehavior` setting
- Tests: insert-mode transition logic, focus-change handling

### V-M3: Link hints (PR #3, → 0.3.0)

- `LinkHintEngine` — AX traversal, label algorithm, viewport filtering
- `HintOverlayWindow` — SwiftUI labels, click dispatch
- Bindings: `f` `F` `gi` `gs`
- Filter-by-text + label-prefix matching
- Tests: label algorithm, hint state-machine transitions (mocked traversal)

### V-M4: Apple Events bridge + vomnibar + clipboard (PR #4, → 0.4.0)

- `SafariBridge` actor + AppleScript templates
- `VomnibarWindow` + URL/bookmark/tab search
- Bindings: `o O b B T yy yf p P`
- Apple Events permission: when the user first opens vomnibar (or invokes `yy`), if Apple Events permission hasn't been granted yet, fall back to opening the onboarding window's Apple Events row instead of letting the AppleScript call fail silently. The onboarding "Grant…" button sends a no-op AppleScript to Safari to trigger the TCC prompt.
- Onboarding wizard expanded from 2-permission (V-M2) to 3-permission flow
- Tests: SitesStore, mocked SafariBridge, vomnibar search/sort

### V-M5: Per-domain disable + suspend (PR #5, → 0.5.0)

- `SitesStore` + Sites tab in Settings
- URL-change observer wires through to mode `.disabled`
- "Disable on this site" / "Suspend until reload" menu items
- `TabSuspendTracker`
- `Esc Esc` toggle-suspend chord
- Tests: pattern parsing/matching exhaustively

### V-M6: Distribution + onboarding polish + 1.0 (PR #6, → 1.0.0)

- Onboarding wizard polished (3-permission flow, polling, illustrations)
- Bindings tab in Settings (read-only reference card)
- App icon refinement
- README marketing pass
- GitHub repo creation, CI secrets provisioning (user task)
- `package_release.sh` + `update_homebrew_tap.sh` adapted from LayerKeys
- `.github/workflows/release.yml` adapted
- Homebrew tap entry: `TaylorFinklea/homebrew-tap/Casks/vimkeys.rb`
- Smoke-test checklist `docs/manual-tests/v1.0-smoke.md`

### Definition of done per milestone

Per LayerKeys convention: every checklist box checked AND
`xcodebuild test -scheme VimKeys -project VimKeys.xcodeproj -destination 'platform=macOS'`
passes AND manual-test checklist for that milestone passes on Taylor's Mac.

### Codex iteration loop

Each PR opened against `main`, gets brief code review (Taylor, ad hoc,
or via Claude-driven `pr-review-toolkit`), then merges. Codex does not
release — that's a manual `git tag v<version> && git push --tags` step
that triggers `release.yml`. Human approval gates each ship.

## Out of scope at v1.0

Be ruthless about what doesn't ship. Each item below is a deliberate
"not at v1" call.

- **User-customizable bindings** — Bindings tab is read-only. Defer to v1.x.
- **Tab switching bindings** (`J`/`K`) — already covered by Cmd+H/L App Shortcuts.
- **Other browsers** — Safari + Safari Tech Preview only.
- **Other web-view-hosting apps** (Mail, Messages preview) — no.
- **General "vim mode for any text view"** — different product.
- **Caret browsing** (`v` to enter visual-select-text mode) — defer.
- **Yank-as-markdown / yank-as-link** — defer; `yy` only copies raw URL.
- **Custom search engines** (Vimium has `:tabnew google` syntax) — vomnibar at v1 hard-codes Google for empty-result fallback; defer multi-engine.
- **Per-domain key remap / partial disable** — only full disable at v1.
- **Fuzzy match in vomnibar** — substring only.
- **Import/export of Sites list** — UserDefaults only at v1.
- **Bookmark hierarchy in vomnibar** — flat-list display only.
- **Multiple monitors edge cases** — overlay positioning targets the screen of Safari's focused window; "across multiple Spaces" not promised.

## Open questions documented for build-time

These don't block the spec; flagged so future-you doesn't re-derive:

- **AX traversal cost on large pages**. 1000+ candidate links walked
  synchronously could stall the AX call. Mitigations: background queue
  (already specified) + 200 ms budget + "scanning…" indicator.
- **Hint label collision when `i` is pressed mid-hint**. Default
  alphabet excludes `i` for this reason. Document if user changes the
  alphabet to include `i`.
- **Mode persistence across tab switches**. Same `.normal(.none)`
  mode survives tab switches as long as Safari stays frontmost. Per-tab
  state (typed-buffer in find, etc.) does NOT persist — overlays are
  dismissed on tab switch via `kAXFocusedWindowChangedNotification`.
- **Hash navigation (`example.com#section`) triggering URL-change
  observer**. Probably acceptable — same host, blocklist match doesn't
  change. But the suspend-until-reload tracker could clear too eagerly.
  Refine if it bites.
- **Reduced motion accessibility setting** — should hint overlay
  animate? Default = no animation (immediate appear/dismiss). If a user
  asks, respect `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.

## References

- Decision context: `docs/decisions/safari-vim-nav.md` in the LayerKeys repo
- LayerKeys repo: https://github.com/TaylorFinklea/layerkeys
- LayerKeys ADRs: `.docs/ai/decisions.md` in that repo
- Vimium documentation: https://github.com/philc/vimium
- Vifari source: https://github.com/dzirtusss/vifari
- macOS Accessibility API: `AXUIElement` (CoreFoundation),
  `AXIsProcessTrustedWithOptions`, `AXObserver`
- Quartz Event Services: `CGEvent.scrollWheelEvent`,
  `CGEvent.tapCreate`, `CGEventPost`
- Sparkle: https://sparkle-project.org
