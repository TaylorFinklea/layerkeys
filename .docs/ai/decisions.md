# Decisions

> Architecture decision records. Append-only — one entry per decision.

## [2026-04-18] Product identity: minimalist nav + numpad, done right

**Context**: First roadmapping session. Needed a long-term framing before
sequencing milestones, since "Karabiner-lite with user-defined layers" and
"hyper-key launcher" are both natural-feeling extensions of the current code.

**Decision**: Lock the product identity to "the navigation layer and numpad
layer, done right." Two layers, no more. No user-defined layers, no per-app
rules, no leader-key/launcher behavior.

**Alternatives considered**:
- Karabiner-lite with user-defined layers and per-app rules.
- Hyper-key leader app (Raycast-of-keys) where layers are one capability.
- Defer the framing.

**Rationale**: A minimalist scope is defensible against Karabiner forever
(simpler, GUI-only, zero JSON), gives a clear "done" line, and the work that
comes from polishing two well-defined layers compounds (notarization,
onboarding, layout localization) instead of fanning out into config-system
design. Pivoting to the launcher framing is a different product.

## [2026-04-18] Milestone sequencing: capability-first, polish last

**Context**: User wanted all four candidate themes (notarization, reliability,
catalog expansion, configurable trigger) to land before v1.0.

**Decision**: Sequence as M1 source-key catalog → M2 configurable trigger
→ M3 reliability → M4 notarized v1.0 (which bundles onboarding,
launch-at-login, Sparkle, app icon, and the v1.0 release tag).

**Alternatives considered**:
- Notarize first so every release after is signed.
- Reliability + notarization first, ship polished v1.0 with current features,
  then expand.
- One mega-milestone covering everything.

**Rationale**: Configurable triggers are a v1 expectation; shipping v1.0
without them and adding them in v1.x would feel like a forgotten feature.
The expanded source-key catalog is a hard prerequisite for the trigger
picker. Reliability lands right before the public push so we're not asking
strangers to test our wake-from-sleep handling. Notarization is bundled
into M4 because it's the meaningful moment for a clean public release;
pre-v1.0 builds keep the `xattr` workaround.

## [2026-04-18] Apple Developer ID available; M4 will real-notarize

**Context**: Without a Developer ID, notarization can't happen and the cask
keeps needing the `xattr -dr com.apple.quarantine` workaround.

**Decision**: M4 will include full Developer ID Application signing,
`notarytool` submission, and stapling, with the cert and notary credentials
stored as GitHub Actions secrets.

**Alternatives considered**: Skip notarization indefinitely; defer the
decision; wait until M4 starts to provision.

**Rationale**: User has a Developer Program account. The marginal cost of
doing it properly is a one-time CI configuration; the user-visible payoff
(no `xattr`, Gatekeeper-clean install) is enormous and is the whole point
of M4.

## [2026-04-18] Distribution: Homebrew-only install + Sparkle in-app updates

**Context**: Today install is Homebrew-only with no in-app updater. Options
considered: add a DMG landing page, add Sparkle, add Mac App Store, stay
Homebrew-only.

**Decision**: Stay Homebrew-only for install/discovery. Add Sparkle in M4
for in-app updates so users (brew or otherwise) don't have to remember to
run `brew upgrade --cask layerkeys`.

**Alternatives considered**:
- Add a DMG download from a landing page (rejected — extra surface, brew is
  fine for the target audience).
- Mac App Store (rejected — sandboxing is fundamentally incompatible with
  global `CGEventTap`; the app's core feature would have to be removed).
- Stay Homebrew-only with no Sparkle (rejected — manual updates degrade the
  experience and slow our ability to ship fixes).

**Rationale**: Homebrew is the right discovery channel for the audience
(macOS keyboard tinkerers); Sparkle solves the update-latency problem
without forcing users to a different install channel.

## [2026-04-18] Telemetry: fully offline, never

**Context**: Whether to ship analytics or crash reporting (opt-in or
otherwise).

**Decision**: No analytics, no crash reporting, no network calls of any
kind — except Sparkle's appcast fetch starting in M4.

**Alternatives considered**: Opt-in crash reports only; opt-in crash reports
plus anonymous usage; defer.

**Rationale**: A keyboard-event-tapping menu-bar app has the strongest
possible reason to make a privacy promise; "we literally do not phone home"
is a marketing asset and a liability shield. Bug reports come through GitHub
issues. If/when this becomes painful we can revisit.

## [2026-04-18] Numpad layer falls back to nav (current behavior) is intentional

**Context**: When the numpad layer is active and a key isn't in the numpad
map, today's `ResolvedMappings.remappedKeyCode` falls back to the nav map
(so `J` still emits `↓` while in numpad). Could be made exclusive or
configurable.

**Decision**: Preserve the current fall-through behavior. Do not add a
toggle.

**Alternatives considered**: Make numpad layer exclusive; add a "fall
through to navigation" Settings toggle.

**Rationale**: Fits the minimalist identity (no extra toggles). The
fall-through is more useful than surprising in mixed contexts (e.g.
entering form data, navigating between fields and typing numbers). The
behavior is documented in the constraints section of `roadmap.md` so it
doesn't get accidentally changed.

## [2026-04-19] Function keys dropped from M1 source-key catalog

**Context**: The original M1 roadmap listed `Add F1–F12 function keys to
InputKey` alongside digits, punctuation, and the ISO section key. When
actually planning M1, the purpose of F-keys as *source* keys came into
question.

**Decision**: Drop F1–F19 from the M1 source-key catalog. Expose digits,
`[ ] ' ` `` ` `` `-` `=` `\`, and `§` only. Function keys are not added as
sources — not now, not later.

**Alternatives considered**:
- Include F1–F12 for completeness.
- Include F1–F19 so everything is covered at once.
- Defer function keys to a later milestone as sources.

**Rationale**: `InputKey` is the *source* side of a layer binding — the
key you press while holding the trigger chord. Binding F-keys as sources
fights the product's "home-row, done right" thesis: if a user is reaching
for F13, they've already left the home row and could just bind the F-key
directly in macOS. Function keys have real value as *targets* (hold the
trigger, press `H` to emit `F5` for an app shortcut) but that expands
`NavigationTargetKey` / `NumpadTargetKey`, not `InputKey`, and is a
separate product conversation worth having only if real users ask for it.
Keeping the source catalog disciplined to the typing cluster preserves
the minimalist identity.

**Follow-up**: Re-open this decision only if users explicitly request
function keys as targets. Pure curiosity isn't enough.

## [2026-04-19] Space lives in the `.punctuation` Category (labeled "Punctuation & Space")

**Context**: When grouping `InputKey` into `.letters` / `.digits` /
`.punctuation` / `.iso` for the new sectioned Settings picker, `.space`
needed a home. Options: a single-member `.space` category, include in
`.punctuation`, or include in `.letters` (no).

**Decision**: Put `.space` in `.punctuation`; label the section
"Punctuation & Space" so the picker is self-explanatory.

**Rationale**: A one-item section is worse UX than a slightly broader
label, and `.space` is structurally the only other "non-letter typing
cluster" key. This avoids both a lonely section and an unlabeled
mystery-bucket.

## [2026-04-20] M2 trigger model: `InputKey` + modifiers, no new enum

**Context**: M2 planning. Original proposal floated a separate `TriggerKey`
enum that would be a superset of `InputKey` plus F1–F19, Escape, Return,
Tab, Delete, and CapsLock. User pushed back with "Why are we still doing
function keys?" — correctly pointing out the inconsistency with M1's
dropped function-key decision.

**Decision**: Trigger key is an `InputKey`. Modifiers are a
`Set<TriggerModifier>` (⌘ ⌃ ⌥ ⇧). Numpad sub-trigger is an `InputKey`.
No new `TriggerKey` enum. Tap-to-Escape is a user toggle on
`TriggerProfile` (default on). Modifier-only triggers (e.g. right-⌘
alone), CapsLock, and function keys as triggers are all deferred to a
hypothetical "advanced triggers" milestone.

**Alternatives considered**:
- Separate `TriggerKey` superset with F-keys + special keys (original
  proposal, rejected for M1 inconsistency).
- Reuse/expand `InputKey` to include F-keys (rejected because it reverses
  the M1 `decisions.md` 2026-04-19 ADR).
- Support modifier-only triggers with full left/right distinction
  (rejected for M2 scope — needs NSEvent device-dependent flags).
- Auto-disable tap-to-Escape for "dumb-to-tap" triggers (rejected as
  surprising; explicit user toggle is clearer).

**Rationale**: Consistency with M1's home-row thesis. The trigger is
pressed every time the user wants a layer; reaching for F13 each time
betrays the whole point. Users who want modifier-y triggers get there
via chords (`⌃Space`, `⌘/`, `⌥A`, etc.), not via special single keys.
One enum to maintain. The Triggers tab's key picker is literally the
same `Section`-grouped `InputKey` picker the `BindingRow` already uses.

## [2026-04-20] M2 migration: default-inject trigger field on decode

**Context**: Existing users have pre-M2 saved profiles in `UserDefaults`
that don't have a `triggers` field. Needed a migration strategy.

**Decision**: Custom `init(from decoder:)` on `MappingProfile` that does
`triggers = try container.decodeIfPresent(TriggerProfile.self, forKey:
.triggers) ?? .default`. No schema version number, no legacy-shape
conversion.

**Alternatives considered**:
- Schema-versioned migration (`schemaVersion: Int` field, explicit
  upgrade path).
- Legacy-shape conversion mirroring the existing `legacyDefault` pattern.

**Rationale**: Simplest Swift-idiomatic approach. Default-inject also
handles the forward-compatibility case (future non-breaking additions
need only another `decodeIfPresent`). Schema versioning would be
premature; we don't have a migration chain worth organizing yet.

## [2026-04-20] Non-US keyboard-layout glyph labels deferred out of M3

**Context**: M3 was originally scoped to include a "non-US layout sanity
check" — translate each `InputKey`'s title to the user's current
keyboard-layout glyph via `TISCopyCurrentKeyboardInputSource` +
`UCKeyTranslate`, and refresh on
`kTISNotifySelectedKeyboardInputSourceChanged`.

**Decision**: Defer. M3 ships with English-only labels. Keycodes are
already layout-independent (physical scancodes), so functionality works
on non-US layouts; only the label text is US-centric. Revisit during M4's
polish pass, or when a real non-US user files an issue.

**Alternatives considered**:
- Minimal version: show `"semicolon (ö)"` on German layouts in the picker.
- Full version: replace the English label entirely and observe input-source
  changes live.

**Rationale**: Carbon/TIS glue is significant surface area for a UI
refinement with no reliability value. M3's charter is "make the tap
survive everything macOS throws at it" — localization doesn't fit. The
code change is entirely additive when we do it; nothing locked in M3
precludes the later work.

## [2026-04-20] M3 testable seam via pure `decide()` value, not a CGEvent protocol

**Context**: `EventTapEngine.handle` had zero test coverage because it
interleaved `CGEvent` side effects (mutating keycode / flags, calling
`CGEvent.tapEnable`, posting synthetic events) with pure state-machine
logic. Opus-tier backlog item called for a unit-testable seam. Two
shapes were on the table: (a) extract a pure `EventAction` value that
the state machine returns, or (b) wrap `CGEvent` in a protocol so the
engine becomes parameterized over a test double.

**Decision**: Shape (a) — pure `EventAction` enum with a
`LayerStateMachine.decide(...)` method. Engine becomes a thin
CGEvent-side-effect switch over the action.

**Alternatives considered**: CGEvent protocol wrapper (rejected —
larger surface area, more ceremony, doesn't actually test more logic).

**Rationale**: The interesting branches are all in the decision
(which action to take), not in the side effects (how to apply it).
Testing the decision with plain values + explicit `CGEventFlags` bit
sets is cheaper and more precise than mocking a whole CGEvent.
Matches the existing test style (`LayerStateMachine` tests use
concrete keycode values, not mocks). Side-effect paths stay small
enough to eyeball; the `Unmanaged.passRetained` contract collapsed to
a single `.remap` branch as a bonus.

## [2026-04-18] Backlog `tier3_owner: claude`

**Context**: The shared workflow lets repos pick which agent owns Opus-tier
backlog work.

**Decision**: Set `tier3_owner: claude` in `.docs/ai/roadmap.md`. Claude
may execute Opus-tier items (e.g. design-heavy refactors of `EventTapEngine`,
new test seams) when the user runs `/process-backlog-opus`.

**Alternatives considered**: `codex`, `copilot`, `unassigned`.

**Rationale**: User-stated preference. Claude is the active agent in this
repo; the other tools can still pick up Haiku/Sonnet items from the same
backlog.

## [2026-04-29] M4 split into M4a (release pipeline) + M4b (UX polish)

**Context**: M4 originally bundled signing, notarization, Sparkle, launch-at-login,
onboarding, conflict warnings, app icon, and marketing pass into one
milestone. That's a large chunk and the dependencies are skewed:
signing/notarization/Sparkle/launch-at-login are pipeline infrastructure
gated on external prereqs (Apple Developer ID cert, notarytool credential,
Sparkle keys, GitHub repo + secrets), while richer onboarding, the
conflict-warnings UI, the icon refresh, and the marketing pass are
UI work that needs the pipeline to already exist.

**Decision**: Split M4 into M4a (release pipeline, ships 0.2.0 — Gatekeeper-clean,
auto-updating, optional launch-at-login, UI otherwise unchanged) and M4b
(richer onboarding, conflict warnings, hand-designed icon, marketing pass,
ships 1.0.0).

**Alternatives considered**: keep the single M4 bundle and ship one giant
1.0.0; ship the polish before the pipeline; ship the pipeline as a 0.1.1
bugfix release.

**Rationale**: The blast radius is different — M4a wires distribution; M4b
shapes first impressions. Verifying them independently is valuable: a real
user installing a notarized 0.2.0 today validates the whole pipeline
end-to-end, and that lesson is worth more before a 1.0.0 onboarding push
than baked into it. Naming the split-out 0.2.0 also signals to users that
this isn't *the* 1.0 release — the polish is still to come.

## [2026-04-29] Sparkle appcast hosted as a GitHub release asset

**Context**: Sparkle needs an `appcast.xml` URL and a place to host signed
release artifacts. Choices: dedicated S3 / Cloudflare / static-host; a
`gh-pages` branch on the repo; the GitHub release asset itself.

**Decision**: appcast lives at
`https://github.com/TaylorFinklea/layerkeys/releases/latest/download/appcast.xml`
— uploaded as a release asset alongside `LayerKeys.zip` by the release
workflow.

**Alternatives considered**:
- `gh-pages` branch (atomic with code; needs Pages plumbing).
- Dedicated CDN (cost + ops surface for a free tool).

**Rationale**: Zero infrastructure, atomic with releases (the appcast and
the zip appear together when CI uploads), public + offline-cacheable, no
Sparkle configuration to wrangle. Trade-off: the URL bakes in our project
name; if we ever fork or rename, the cask needs republishing. Acceptable.

## [2026-04-29] Launch-at-login: default off + one-shot first-launch prompt

**Context**: Some macOS utilities default to "start at login" silently
(power-user expectation); some never auto-start without explicit setup
(least-surprise). Picking sides for LayerKeys.

**Decision**: Default **off**. On first launch (gated by a
`didShowLaunchAtLoginPrompt` UserDefaults flag, scheduled via a deferred
main-actor `Task` from `AppModel.init`) show a single `NSAlert` with
"Start at Login" / "Not Now". The toggle also lives in Settings → General
so the user can flip it later either direction.

**Alternatives considered**:
- Default on with a Settings toggle to turn it off.
- Default off, no prompt — discovery via Settings only.

**Rationale**: A menu-bar app booting itself at login without asking
violates "the user installed an app, that app should not now be a login
item until they say so." Hiding the toggle behind Settings is the other
failure mode: many users never visit Settings. The one-shot prompt at
first launch is the cheapest discovery path and shown exactly once per
user, ever.

## [2026-04-29] M4a phase order: A (in-app) → B–F (signing/CI/release/docs)

**Context**: M4a as originally written assumed all external prereqs were in
place from day one. They weren't. At resumption: the Developer ID cert
was the only one provisioned; the GitHub repo `TaylorFinklea/layerkeys`
doesn't exist yet (the cask URL has been pointing at a 404 since 0.1.0);
no Sparkle keypair; no notarytool credential. This will be LayerKeys's
*first* public release, not an upgrade of an existing 0.1.0 install base.

**Decision**: Reorder M4a as Phase A (pure in-app code, no external deps)
→ B.1 (user-provisions notarytool credential) → B.2 (signing/notarization
in script — testable locally with `SKIP_NOTARIZE=1`) → C (Sparkle keys,
fully automatable from the Sparkle release tarball) → D (GitHub repo +
secrets, user-collaborative) → E (cut 0.2.0) → F (README + handoff docs).

**Alternatives considered**:
- Front-load every prereq before any code (slower to demonstrate progress;
  user has to provision multiple credentials before seeing anything).
- Strict serial blocking on each prereq (serializes too much; nothing
  ships until everything is in place).

**Rationale**: Phase A delivers a meaningful, shippable, testable chunk
(Sparkle wired, launch-at-login toggle, Settings General tab, +4 tests)
without any external dependency. Phases B–F can interleave with user
actions as credentials get provisioned. The plan's original
M4a.1 → M4a.7 design intent is preserved — only execution sequence
changes to fit reality.

## [2026-04-29] Release script always builds unsigned, then signs explicitly

**Context**: `package_release.sh` had to handle two environments: local
(Dev ID cert in login keychain, ready to sign at build time) and CI (cert
imported into a temp keychain by the workflow, only available *after*
`xcodebuild` runs). Two natural shapes: tell xcodebuild to sign with
Developer ID directly via `CODE_SIGN_STYLE=Manual` + `CODE_SIGN_IDENTITY`,
or always build unsigned and sign explicitly with `codesign` post-build.

**Decision**: Always build unsigned (`CODE_SIGNING_ALLOWED=NO`), then
sign explicitly with `codesign --force --options runtime --timestamp
--deep`. The same script runs locally and in CI; the only difference is
how the keychain gets the cert.

**Alternatives considered**: Tell xcodebuild to sign during build with
`CODE_SIGN_STYLE=Manual` + Developer ID identity. Cleaner in some ways
(Xcode handles recursive framework signing automatically), but couples
the build step to the signing step, makes CI's "import cert *after*
build" pattern impossible, and means `SKIP_CODESIGN=1` would require
flipping a different lever.

**Rationale**: One contract for both environments, simpler debugging
(unsigned build is its own checkpoint), `--deep` handles Sparkle
.framework's nested binaries (Autoupdate, XPCServices/*.xpc, Updater.app)
correctly — verified locally via `SKIP_NOTARIZE=1 ./scripts/package_release.sh`
with `codesign --verify --deep --strict` passing on the result. Two
escape hatches keep dev workflows ergonomic: `SKIP_CODESIGN=1` for
contributors without a Developer ID cert, `SKIP_NOTARIZE=1` for fast
local iteration.

## [2026-05-06] M4b menu-bar icon: custom SwiftUI keycap glyph over SF Symbols

**Context**: The pre-M4b menu bar showed `Image(systemName: model.mode.symbolName) + Text(model.mode.menuBarLabel)` — three SF Symbols (`circle`, `arrow.up.left.and.arrow.down.right`, `number.square`) paired with hardcoded `LK`/`NAV`/`NUM` text labels, plus an `exclamationmark.triangle.fill` fallback when permission was denied. Two known visibility gaps: (a) listen-only permission state was indistinguishable from "all good," and (b) Sparkle update + tap-error signals lived only in the menu's `lastError` string, not in the menu-bar icon itself.

**Decision**: Replace the SF Symbol + text pair with a single custom SwiftUI `MenuBarIconView` rendering a keycap silhouette as the constant identity, with state-distinct inner content. Seven visual states: off / nav / numpad / denied / listen-only / update-available / tap-error. Drop the text label entirely.

**Alternatives considered**:
- Template image asset catalog (`MenuBarOff.imageset` × 7, PDF, "Render as Template"). Most Apple-idiomatic, but template images are single-color by definition — orange-denied / red-error require either non-template variants (losing automatic system tinting) or a SwiftUI tint override on top of color-baked assets.
- Custom SF Symbol set. Apple's "official" path for designed-from-scratch glyphs, but requires authoring in Apple's SF Symbols app + maintaining `.svg` files in their exact layer-structure format. Heavyweight for 7 closely related glyphs.
- Keep SF Symbols but design distinct ones per state. Generic SF Symbols collapsed onto each other at 16pt menu-bar size during brainstorming mockups; couldn't find 7 distinct, coherent symbols in Apple's library.

**Rationale**: A bespoke silhouette is the small amount of design work that buys ever-distinguishable state visualization at menu-bar size. The keycap metaphor anchors the brand to "keyboard" without competing with the rest of macOS. Visual concept validated during brainstorming via a browser-based mockup grid; revisions to nav/numpad/listen-only kept inner content cleanly inside the cap silhouette.

## [2026-05-06] Path/Canvas rendering over template-image PDFs

**Context**: Once the bespoke design was locked, the rendering choice was: SwiftUI `Path`/`Canvas` (translate validated SVG paths directly to Swift), template-image PDFs in `Assets.xcassets` (Apple-idiomatic), or a custom SF Symbol set.

**Decision**: SwiftUI `Path`/`Canvas`. The validated SVG path strings translate one-to-one into Swift `Path` calls inside a `Canvas` block. Color comes from `.foregroundStyle(variant.tint)` propagating to `.foreground` shading on every stroke/fill — no color baked into assets.

**Alternatives considered**: Template image PDFs (rejected: single-color limitation fights the orange-denied / red-error states). Custom SF Symbol set (rejected: heavyweight authoring path for 7 closely related glyphs).

**Rationale**: Single source of truth — the validated SVG geometry becomes Swift literally. Per-variant tinting via `.foregroundStyle` is trivial (`Variant.tint` returns `.orange` for denied, `.red` for error, `.primary` otherwise). Resolution-independent at any menu-bar size. Easy to iterate on geometry later (nudge a chevron 0.5 units in code, rebuild). Trade-off accepted: lose the automatic system tinting that template images get on appearance changes, but we don't want it for the orange/red states anyway.

## [2026-05-06] Drop the menu-bar text label

**Context**: The previous menu bar showed an icon followed by `LK` / `NAV` / `NUM`. With state-distinct iconography, the text label became redundant.

**Decision**: Remove the `Text(model.mode.menuBarLabel)` element from the `MenuBarExtra` label closure. The new `MenuBarIconView` is the entire visual indicator. Delete `LayerMode.menuBarLabel` and `LayerMode.symbolName` since both have no remaining consumers.

**Alternatives considered**: Keep the text as an explicit "what mode am I in" channel for users who want a readable string. Make the text user-toggleable in Settings.

**Rationale**: Glyph-only matches every other macOS utility convention. The accessibility label on `MenuBarIconView` (`"LayerKeys, navigation layer active"` etc.) gives VoiceOver users a fuller signal than the prior 3-letter strings. A user-facing toggle is feature-creep against the "minimalist nav + numpad, done right" identity.

## [2026-05-06] Variant priority order: error > denied > listen-only > mode

**Context**: With 7 visual states, the resolver needs to decide which variant wins when multiple inputs are active. Two natural orderings: (a) by severity (errors and permissions block the mode signal), or (b) by mode-first (always show what layer you're in, overlay everything else as decoration).

**Decision**: Priority order is `tapErrorActive > permissionState == .denied > permissionState == .listenOnly > mode`. Update badge composes onto listen-only / off / nav / numpad but never onto error or denied.

**Alternatives considered**:
- Mode-first with severity overlays. Rejected: stacking a red ✕ over a 4-way arrow cluster at 16pt is illegible.
- Symmetric composition (error-and-denied each overlay independently). Rejected: incoherent UX (can't be both "no permission" AND "tap died" simultaneously — denied implies the tap was never created).

**Rationale**: Errors and permissions are blocking — they should preempt the mode display because the mode signal is irrelevant when the tap can't function. Listen-only is a partial-failure mode where the layers still work, so we show the listen-only marker but allow the user to infer mode from their interaction (they know whether they're holding the trigger). Update badge composes only on non-alert variants because stacking "update available" on top of "tap error" is incoherent — fix the error first.
