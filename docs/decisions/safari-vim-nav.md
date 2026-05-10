# Decision: Safari vim-style navigation does not belong in LayerKeys

- **Status**: Decided
- **Date**: 2026-05-09
- **Decision owner**: Taylor Finklea
- **Affects**: LayerKeys product scope; potential sibling project

## TL;DR

Safari vim-style navigation (`j/k/h/l` scroll, `d/u` half-page, `gg/G`,
`f` link hints, `/` find, mode-aware skip-in-text-inputs) is **not added
to LayerKeys**. It conflicts head-on with LayerKeys' locked-in identity
("nav + numpad, done right; no per-app rules; no user-defined layers")
and link hints push the implementation into Accessibility-tree
introspection of WebKit content — a meaningful compliance escalation
beyond what LayerKeys' "remaps keys" posture asks for.

It will instead be specified as a **sibling project** that reuses
LayerKeys' plumbing (CGEventTap engine, permissions controller, menu-bar
app skeleton, signing/notarization/Sparkle release pipeline) but ships
as its own notarized Developer-ID app. The sibling is **specified now,
built later** — there is no commitment to a build window. Until and
unless the sibling ships, the personal Mac uses Vifari (Hammerspoon
Spoon, unconstrained) and the work Mac accepts mouse scroll.

## Context

### Capability target

Vim-style Safari navigation on macOS:

| Binding | Behavior |
|---------|----------|
| `j` / `k` | Scroll down / up |
| `h` / `l` | Horizontal scroll |
| `d` / `u` | Half-page down / up |
| `gg` / `G` | Top / bottom of page |
| `f` | Link hints — overlay home-row labels on every visible link, type label to click |
| `/` | Find in page |
| (mode awareness) | Disable when focus is in a text input |
| `Esc` | Exit mode |

Tab switching is **out of scope** — already handled by macOS App
Shortcuts binding `Cmd+H` / `Cmd+L` to Safari's "Show Next Tab" /
"Show Previous Tab" menu items.

### Existing landscape

- **Vimari** (Safari Web Extension): last release v2.1.0 (September 2020).
  Open issues from 2024 and 2025 unanswered. Still functional but
  unmaintained.
- **Vifari** (Hammerspoon Spoon): pure Lua, uses Hammerspoon's
  Accessibility-API bindings (`hs.axuielement`). Solves the problem
  cleanly on a personal Mac. Closest existing fit.
- **Vimarily**, **various forks**: same trade-offs as Vimari (sandboxed
  Safari Web Extension vs. native AX traversal).

### Constraint that drives this decision

The work Mac is **HIPAA-compliant / MDM-managed**. Hammerspoon is
unlikely to clear security review:

- Requires Accessibility API
- Auto-executes arbitrary Lua from `~/.hammerspoon/init.lua` with no
  script-level signing
- Same blocker hits Karabiner complex modifications using event taps,
  BetterTouchTool, and Keyboard Maestro

The Safari Web Extension path (Vimari, Vimarily) is more compliance-
friendly (sandboxed) but has the App Store distribution / build-from-
source friction and is unmaintained.

The real decision target is therefore: **is a work-Mac-viable
solution achievable through LayerKeys (or a sibling)?**

## What LayerKeys is today

(Notes from a fresh read of the repo, May 2026.)

### Architecture

- **`LSUIElement` SwiftUI menu-bar app**, single in-process target.
  No kernel extension, no daemon, no XPC helper.
- **`EventTapEngine`** (`LayerKeys/EventTapEngine.swift`): owns a
  `CGEvent.tapCreate` handle on a dedicated `LayerKeys.EventTap`
  thread with its own `CFRunLoop`. Tap is `.cgSessionEventTap` /
  `.headInsertEventTap` / `.defaultTap`, listening on `keyDown` +
  `keyUp` only.
- **`LayerStateMachine`** (`LayerStateMachine.swift`): pure value type,
  no Quartz dependencies beyond `CGEventFlags`. Owns the trigger-hold
  state, mode transitions (off / nav / numpad), and the
  tap-Control+Space → Escape heuristic (`escapeTapThreshold = 200ms`).
  Trivially unit-testable.
- **`KeyCatalog.swift`**: single source of truth for `InputKey`,
  `NavigationTargetKey`, `NumpadTargetKey`, `MappingProfile`, and
  precomputed `ResolvedMappings`.
- **`PermissionController.swift`**: `CGPreflightListenEventAccess`
  (Input Monitoring) + `CGPreflightPostEventAccess` (Accessibility).
  App can run in `.listenOnly` state — remaps work, but tap-to-Escape
  replay is suppressed.

### Permissions requested today

- **Input Monitoring** — required (`CGPreflightListenEventAccess`).
- **Accessibility** — optional (`CGPreflightPostEventAccess`); only
  used to post the synthetic Escape replay on tap-trigger.

### Scope today

Strictly a layered keymapper. Two layers (nav + numpad). No per-app
awareness. No accessibility-tree introspection. No scroll-event
synthesis (only `keyDown` / `keyUp` events are tapped and
`CGEvent`-posted, and only `Escape`).

### Distribution / signing

- **MIT licensed**, source on GitHub at
  `TaylorFinklea/layerkeys`.
- **Developer-ID signed and Apple-notarized** (M4a, shipped 0.2.0 in
  May 2026). Stapled, `spctl --assess` reports
  `source=Notarized Developer ID`.
- **Sparkle 2.x in-app updates**, EdDSA-signed appcast pulled from the
  GitHub Releases endpoint.
- **Homebrew cask** (`TaylorFinklea/tap/layerkeys`) is the install
  channel.
- **Fully offline.** No analytics, no crash reporting, no network
  calls — *except* Sparkle's appcast fetch.

### Per-app awareness

**None.** LayerKeys does not call `NSWorkspace.frontmostApplication`
or anything equivalent. The trigger chord behaves the same in every
app.

### Scroll-event synthesis / AX introspection

**None.** The only synthesized event is the keyboard `Escape` replay
in `EventTapEngine.postEscapeTap(flags:)`. No `CGEvent.scrollWheelEvent`,
no `AXUIElement` calls anywhere in the tree.

### Locked-in product identity (from `.docs/ai/decisions.md` and
`.docs/ai/roadmap.md`)

The following decisions are **explicit ADRs**, not casual preferences:

- 2026-04-18: "Lock the product identity to 'the navigation layer and
  numpad layer, done right.' Two layers, no more. **No user-defined
  layers, no per-app rules, no leader-key/launcher behavior.**"
- 2026-04-18 (telemetry): "No analytics, no crash reporting, no network
  calls of any kind — except Sparkle's appcast fetch."
- Constraints in `roadmap.md`: "**Layer model stays minimal:**
  navigation + numpad only. … New product ideas in those directions
  belong in a **separate project.**"

These ADRs were written precisely to defuse "natural-feeling
extensions" like Karabiner-lite-with-user-defined-layers and
hyper-key launchers. Safari vim nav is the same shape of extension —
it would have been pre-rejected if it had come up at the M0 framing
session.

## Fit analysis: is Safari vim nav a natural extension or scope creep?

### A. Architectural fit (could it be done)

| Capability | Already in scope? | New surface |
|---|---|---|
| Detect Safari frontmost | No | `NSWorkspace.frontmostApplication.bundleIdentifier` — trivial, no new permission |
| Scroll synthesis (`j`/`k`/`d`/`u`/`gg`/`G`) | No | `CGEvent.scrollWheelEvent` — within current `CGRequestPostEventAccess` (Accessibility) scope |
| Find in page (`/`) | No | Synthesize `Cmd+F` keydown/up — within Accessibility scope |
| Mode awareness in text inputs | No | `AXUIElementCopyAttributeValue` to read focused element role — **new** capability surface |
| Link hints (`f`) | No | Walk Safari's `AXWebArea` subtree, read every link's `AXTitle` / `AXURL` / position; render an overlay; consume keystrokes; synthesize click — **significant** new capability surface |

So the minimum subset (j/k/d/u/gg/G + Cmd+F) is implementable inside
LayerKeys' current architecture (event tap + key/scroll synthesis +
one `NSWorkspace` check). The **must-have** subset, including link
hints, requires AX tree traversal of WebKit web content — a
meaningfully larger capability than "remaps keys."

### B. Identity fit (should it be done)

No. It violates three locked-in ADRs:

1. "Two layers, no more." Safari vim is effectively a third layer
   (per-app, conditional).
2. "No per-app rules." Safari vim is *definitionally* a per-app rule.
3. "New product ideas in those directions belong in a separate
   project." This is the explicit escape valve the ADRs reserve for
   exactly this situation.

### C. HIPAA / work-approval angle

LayerKeys' compliance posture today:

- Notarized Developer-ID binary (auditable provenance)
- MIT-licensed, source on GitHub (auditable behavior)
- Two well-scoped permissions (Input Monitoring + optional
  Accessibility)
- No network except Sparkle (one well-known endpoint)
- Sees: every keystroke (because Input Monitoring is unavoidably
  global), but **acts** only on the trigger chord and remaps within
  layers
- Reads no window content, no AX tree, no app state, no clipboard

This is the kind of "narrowly scoped, fully auditable" posture that
*can* clear a HIPAA/MDM review, especially with the user able to
point at the source and say "here is every CGEvent we post, here is
every system call we make."

**Adding Safari vim nav to LayerKeys would move it across a
compliance line:**

- "Reads which app is frontmost" — trivial, defensible.
- "Synthesizes scroll events" — defensible (still just keyboard-input-
  shaped behavior).
- "Reads the AX tree of WebKit content" — *qualitatively different*.
  This is the capability to enumerate links, titles, and positions
  in any web page the user views in Safari. From a security review
  perspective, this is no longer a keymapper — it is an app that can
  read web page contents through the Accessibility API. A reviewer
  might reasonably bucket it with screen-reader / scraper tools and
  ask follow-up questions LayerKeys today does not invite.

The user's working hypothesis is that LayerKeys-class scope is
likely to clear MDM review (vs. Hammerspoon's auto-execute-arbitrary-
Lua posture). **That hypothesis is plausible but untested.** It
matters that we don't burn it on the first feature that enlarges the
capability surface.

A more compliance-friendly architecture for the *feature itself* than
either layerkeys-with-AX or Hammerspoon would be a **Safari Web
Extension** (the Vimari approach): sandboxed, runs JavaScript in page
context, no Accessibility grant required, distributable via the App
Store. The trade-offs: App Store distribution friction, fork-and-
maintain a dormant codebase, and it's no longer the same architecture
or release pipeline as LayerKeys (i.e. we don't share plumbing).

## Options considered

### Option 1: Add full Vimium-style mode to LayerKeys

**Reject.** Violates three explicit ADRs. Adds AX tree introspection
to a binary whose compliance story today rests on *not* having that
capability. Burns the "narrow scope, easy to audit" review posture
on a feature that contradicts the product identity. Pollutes a
codebase whose simplicity is the point.

### Option 2: Add minimal subset (scroll synthesis only, no link hints)

**Reject, but with feeling.** This is the most tempting option
because it stays inside LayerKeys' technical capability envelope:
no new permission grants, just `CGEvent.scrollWheelEvent` posting
gated on `NSWorkspace.frontmostApplication.bundleIdentifier ==
"com.apple.Safari"`. Implementable in maybe 200 lines.

But:
- It still violates "no per-app rules" — that ADR is binary, not
  proportional.
- The user's stated capability target includes link hints as
  must-have. Shipping half the feature inside LayerKeys *and*
  building the rest in a sibling is the worst of both worlds (two
  places to fix bugs, two compliance stories, the LayerKeys half
  becomes vestigial when the sibling exists).
- Once the precedent of "Safari-aware behavior in LayerKeys" is set,
  every subsequent app-specific tweak is now a smaller leap.

### Option 3: Don't add it, accept Vifari personal + mouse on work

**Reject.** This is the safe option but it leaves real productivity
on the table on the work Mac, *and* it loses the chance to ever build
a HIPAA-compliant vim-Safari tool that strangers in a similar bind
could also use. The whole point of LayerKeys' compliance posture is
that "narrowly scoped notarized native app" is a viable category for
constrained Macs; this is that category's natural second product.

### Option 4: Don't add it to LayerKeys; spec it as a sibling project

**Selected.** Honors the LayerKeys ADRs (this is exactly the escape
valve those ADRs name). Lets the new capability surface (frontmost-
app detection, AX traversal of WebKit) be reviewed as its own thing
by future MDM/security review, distinct from the layerkeys.app
binary that the user already trusts. Reuses the plumbing that
matters: CGEventTap engine, permissions controller, menu-bar
skeleton, signing/notarization/Sparkle/CI release pipeline. Spec
now, build later — no commitment to a build window.

## Decision: Option 4

Specify a sibling project. Don't build it yet.

### Sibling project sketch

Working name: **VimKeys** (provisional — open to a better name. Other
candidates: WebHome, RowReach, Hop. Avoid generic "Safari Vim" lest it
sound like a Vimari fork.)

#### Identity

"Vim-style home-row navigation in Safari, done right." Same
minimalist ethos as LayerKeys: one job, no leader-key sprawl, no
generalized "any web view, any app" mode.

#### Scope (v1)

- `j` / `k` — line scroll down/up (3-line `CGEvent.scrollWheelEvent`)
- `h` / `l` — horizontal scroll
- `d` / `u` — half-page scroll
- `gg` / `G` — top / bottom (synthesize `Cmd+Up` / `Cmd+Down`)
- `/` — find in page (synthesize `Cmd+F`)
- `f` — link hints (AX traversal of `AXWebArea`, overlay home-row
  labels via a transparent `NSPanel`, type label to click)
- Mode-aware: skip when focused AX element is editable
  (`AXTextField` / `AXTextArea` / `AXEditableText`-roled)
- `Esc` — exit mode
- Activation: only when `NSWorkspace.frontmostApplication.bundleIdentifier
  == "com.apple.Safari"`. No per-domain rules.

#### Explicitly out of scope (v1)

- Tab switching (already handled via macOS App Shortcuts)
- History nav (Safari's own `Cmd+[` / `Cmd+]` is fine)
- Yank / paste / clipboard ops
- Per-domain disable list (defer to v1.x)
- Other browsers (Chrome, Firefox, Arc) — Safari-only at v1; revisit
  if a real user asks
- Other web-view-hosting apps
- General "vim mode for any text view" — that is a different product

#### Permissions

- **Input Monitoring** (`CGRequestListenEventAccess`) — same as
  LayerKeys.
- **Accessibility** (`CGRequestPostEventAccess` *and*
  `AXIsProcessTrustedWithOptions`) — same prompt the user already
  sees, but *substantively* used: not just for posting events but
  for reading the AX tree. Onboarding copy must be honest about this.

#### Compliance escalation vs. LayerKeys baseline

Be explicit in the security-review submission:

| Capability | LayerKeys | VimKeys |
|---|---|---|
| Reads keystrokes globally | Yes (Input Monitoring) | Yes |
| Acts on keystrokes globally | Only on configured trigger chord | Only when Safari is frontmost AND mode is on |
| Synthesizes keyboard events | Only `Escape` (one virtual key) | `Escape`, `Cmd+F`, `Cmd+Up`, `Cmd+Down`, mouse click |
| Synthesizes scroll events | No | Yes (`CGEvent.scrollWheelEvent`) |
| Reads frontmost app | No | Yes (`NSWorkspace.frontmostApplication`) |
| Reads AX tree | No | **Yes**, restricted to Safari's AX tree, on-demand only when `f` is pressed (not continuously) |
| Network calls | Sparkle appcast only | Sparkle appcast only |

The "AX tree read of Safari" line is the load-bearing escalation. The
mitigation that makes it defensible:

1. **On-demand only.** AX tree is walked when `f` is pressed, not on
   every keystroke or page load.
2. **Safari-scoped only.** Code path checks frontmost bundle ID
   before any AX call.
3. **Read-only.** App reads link positions and labels; it does not
   modify the page, inject scripts, or persist any AX-derived data.
4. **No network egress of AX-derived data.** Same offline posture as
   LayerKeys.
5. **MIT licensed, source published.** Reviewer can audit every
   AXUIElement call site.

#### Shared plumbing — what to extract

The following is current LayerKeys code that is **architecture, not
identity** and could plausibly be reused without copy-pasting:

| LayerKeys file | Reuse strategy |
|---|---|
| `EventTapEngine.swift` (engine thread, tap lifecycle, re-enable on disable) | Extract to a shared SPM package, e.g. `KeyTapKit`. Generic over the per-event handler. |
| `EventTapService.swift` (façade + sleep/wake re-arm) | Move to `KeyTapKit` alongside engine. |
| `PermissionController.swift` | Move to `KeyTapKit`. Add `AXIsProcessTrustedWithOptions` wrapper alongside the existing `CGRequest*` ones. |
| `LaunchAtLoginController.swift` | Move to `KeyTapKit`. |
| Menu-bar skeleton (`LSUIElement`, `MenuBarExtra`, settings scene plumbing in `LayerKeysApp.swift`) | Probably *not* worth extracting — too much per-app variation in what shows in the menu and what tabs the settings has. Copy-and-adapt is fine for a one-of-two-apps situation. |
| Sparkle integration (`SparkleUpdateObserver`, EdDSA key plumbing) | Each app keeps its own EdDSA keypair and appcast URL, but the observer pattern is identical. Extract to `KeyTapKit`. |
| `scripts/package_release.sh` + `scripts/update_homebrew_tap.sh` + `.github/workflows/release.yml` + `.github/workflows/ci.yml` | Each app has its own copy at first; reconcile only if the divergence stays trivial. **Don't pre-extract** — premature abstraction. |
| Notarytool keychain profile (`layerkeys-notarytool`) | The user already has a Developer ID; provision a separate `vimkeys-notarytool` profile. |

Concretely: **`KeyTapKit` SPM package** containing
`EventTapEngine` + `EventTapService` + `SleepWakeHandler` +
`PermissionController` + `LaunchAtLoginController` +
`SparkleUpdateObserver`. LayerKeys depends on it; VimKeys depends on
it. State-machine logic stays per-app (LayerKeys' `LayerStateMachine`
is identity, not plumbing).

This extraction is **not a prerequisite** to building VimKeys. The
sibling can copy LayerKeys' files at start and the shared package
can be reverse-engineered later if the divergence stays small. (See
"sequencing" below.)

#### Repo layout

- New repo: `TaylorFinklea/vimkeys` (or chosen name).
- Same Homebrew tap: `TaylorFinklea/homebrew-tap` gains a second
  cask file. Existing cask infrastructure handles two casks
  trivially.
- New GitHub Actions workflow mirrors LayerKeys' `release.yml`.
- New EdDSA keypair for Sparkle (do not reuse LayerKeys').

#### Build sequencing (if and when we build)

Roughly mirrors LayerKeys' M1→M4 cadence — capability-first,
polish last:

- **V-M1**: Scroll-only Safari mode. Toggle on/off via a chord
  (`Cmd+Esc` placeholder). `j/k/h/l/d/u/gg/G`, no link hints, no
  mode-awareness, no `f`. Verifies: CGEventTap-based scroll
  synthesis works, frontmost-app gating works, the architecture is
  viable. Ships as 0.1.0.
- **V-M2**: Mode-awareness via AX. Detect editable focused element
  in Safari and skip remapping when focused. `/` (find-in-page)
  added. Ships as 0.2.0.
- **V-M3**: Link hints (`f`). The big one. AX traversal of Safari's
  `AXWebArea`, overlay panel, label algorithm (Vimium-style
  home-row pairs), filtered typing, click synthesis at the chosen
  link's center coordinates. Ships as 0.3.0.
- **V-M4**: Release pipeline (Developer ID signing, notarization,
  Sparkle, Homebrew cask). Mirrors LayerKeys M4a. **At this point**,
  reconsider extracting `KeyTapKit` — by now there will be enough
  duplication signal to extract intentionally rather than
  speculatively. Ships as 1.0.0.
- **V-M5 / polish**: Onboarding, conflict warnings, marketing —
  mirrors LayerKeys M4b.

#### Open questions (for build-time, not now)

These do not block the decision; they are flagged so future-you
remembers what to think about when V-M3 starts:

- **AX traversal cost on large pages.** A page with 500+ links
  walked synchronously could stall the event tap thread. Likely
  needs a background queue + main-thread-overlay-render pattern.
  Vifari's Lua implementation is a useful reference but not
  performance-comparable.
- **Link hint label algorithm.** Vimium uses a length-balanced
  home-row pair scheme. Decide between `asdf`-style or Vimium-style.
  Document the choice.
- **Mode persistence across tab switches and page navigations.**
  Vimium and Vifari both maintain mode across tabs in the same
  window. Decide and document.
- **Per-domain disable list.** Out of scope for v1, but reserve a
  Settings tab spot.
- **Multiple Safari windows.** Mode is per-Safari-app, not
  per-window. Confirm via AX whether this is even a meaningful
  distinction.
- **Safari Technology Preview** (`com.apple.SafariTechnologyPreview`
  bundle ID). Should it activate the mode? Probably yes; document.
- **iCab / Orion / Edge for Mac.** They're WebKit-based and `f`
  could *accidentally* work via AX. Decide whether to whitelist
  Safari only (probably yes; revisit if user demand).

## What this decision does NOT decide

- A build window for VimKeys.
- A name for VimKeys.
- Whether `KeyTapKit` is extracted before or after V-M4.
- Whether VimKeys ever supports browsers other than Safari.
- Whether the sibling project's compliance review actually clears the
  user's work-Mac MDM bar — this is the load-bearing assumption that
  needs validation. The lowest-cost validation step is to first
  attempt to get *LayerKeys itself* approved for the work Mac;
  if LayerKeys clears, VimKeys is a smaller marginal review (same
  posture + an extra AX-traversal ask).

## References

- LayerKeys repo: `TaylorFinklea/layerkeys`
- LayerKeys identity ADRs: `.docs/ai/decisions.md`
  - 2026-04-18 "Product identity: minimalist nav + numpad, done right"
  - 2026-04-18 "Telemetry: fully offline, never"
- LayerKeys roadmap constraints: `.docs/ai/roadmap.md` § "Constraints"
- Vifari (Hammerspoon Spoon): https://github.com/dzirtusss/vifari
- Vimari (Safari Web Extension): https://github.com/televator-apps/vimari
- macOS Accessibility API: `AXUIElement` (CoreFoundation),
  `AXIsProcessTrustedWithOptions`
- Quartz Event Services: `CGEvent.scrollWheelEvent`,
  `CGEvent.tapCreate`
