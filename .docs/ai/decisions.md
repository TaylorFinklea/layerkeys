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
