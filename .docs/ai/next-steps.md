# Next Steps

> Short checklist of exact next actions. Updated at end of every session.

## Immediate

- [ ] Plan **M3: Reliability & correctness pass**. The interesting
  sub-items are tap auto-recovery on sleep/wake (not just
  `tapDisabledByTimeout`), adding a unit-testable seam to
  `EventTapEngine.handle` so we can assert the synthetic-escape tag
  round-trip and `.maskNumericPad` flag transitions without a real
  CGEventTap, and non-US-layout friendly source-picker labels. The
  `EventTapEngine` split into its own file (backlog Sonnet item) is a
  plausible warmup that makes M3's testable-seam refactor easier to
  review.

## Soon

- [ ] Backlog Sonnet-tier: split `EventTapEngine` out of
  `EventTapService.swift` into its own file (pre-M3 warmup; matches the
  pattern we used for M1/M2's `BindingRow` extraction before the
  Triggers tab).
- [ ] Backlog Sonnet-tier: extract the `add/remove/update*Binding`
  duplication in `AppModel` into a generic over a `WritableKeyPath`.
  Low risk; shrinks `AppModel` considerably.
- [ ] Backlog Haiku-tier: `MappingStore.swift` silent `try? save(.default)`
  swallow.

## Deferred

- [ ] "Advanced triggers" milestone (post-M4 at the earliest): F-keys as
  triggers, CapsLock-as-trigger with remap-in-System-Settings help text,
  modifier-only triggers with left/right distinction via NSEvent
  device-dependent flags. All explicitly out of scope today. See
  `decisions.md` 2026-04-20 entry.
- [ ] Apple Developer ID + `notarytool` keychain profile + GitHub
  secrets setup — required before M4.
- [ ] Sparkle EdDSA key generation + appcast hosting decision — required
  before M4's Sparkle work.
- [ ] App icon refresh — defer until M4's polish phase.
- [ ] Function keys as *targets* (expanding `NavigationTargetKey` /
  `NumpadTargetKey`) — still explicitly not a milestone. Revisit only
  on real user demand.
