# Next Steps

> Short checklist of exact next actions. Updated at end of every session.

## Immediate

- [ ] Plan **M2: Configurable trigger**. The new `InputKey.Category`
  grouping from M1 is directly reusable for the Triggers tab's key picker.
  Open questions for the plan phase: how to represent modifier-only
  triggers (e.g. CapsLock alone, right-⌘ alone) since they're not in
  `InputKey`; whether the numpad sub-trigger should accept the full
  `InputKey` catalog or just letters; migration path for pre-M2 saved
  profiles.

## Soon

- [ ] Before M2's Settings "Triggers" tab lands, pick up the Sonnet-tier
  `BindingRow` extraction backlog item — the new tab will want the same
  generic row component, and M1 deliberately did not refactor it.
- [ ] Consider a Haiku-tier follow-up: `InputKey.cases(in:)` runs
  `allCases.filter` each call (49-item scan × 4 sections = 196 per Picker
  render). Cache per category if this ever shows up in a profile. Not
  urgent.

## Deferred

- [ ] Apple Developer ID + `notarytool` keychain profile + GitHub secrets
  setup — required before M4 can begin. Not needed earlier.
- [ ] Sparkle EdDSA key generation + appcast hosting decision (likely the
  GitHub release itself) — required before M4's Sparkle work.
- [ ] App icon refresh — currently a script-generated placeholder; defer
  until M4's polish phase so we don't repaint twice.
- [ ] Function keys as *targets* (expanding `NavigationTargetKey` /
  `NumpadTargetKey`) — explicitly not a milestone today. Revisit only if
  a real user asks. See `decisions.md` 2026-04-19 entry for the rationale.
