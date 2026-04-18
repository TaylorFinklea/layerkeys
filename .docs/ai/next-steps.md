# Next Steps

> Short checklist of exact next actions. Updated at end of every session.

## Immediate

- [ ] Plan **M1: Source-key catalog expansion** via the phase execution
  protocol (`docs/ai-workflows/phase-execution.md` if present, otherwise
  the standard Plan → Clarify → Build → Verify → Report flow). Spec lands
  at `.docs/ai/phases/m1-source-key-catalog.md`.

## Soon

- [ ] After M1 ships, plan **M2: Configurable trigger** — depends on the
  M1 catalog being in place (so the trigger picker has a real superset
  of keys to choose from).
- [ ] Pick up the Sonnet-tier `BindingRow` extraction backlog item before
  M2's "Triggers" tab is added — the new tab will want the same generic
  row component.

## Deferred

- [ ] Apple Developer ID + `notarytool` keychain profile + GitHub secrets
  setup — required before M4 can begin. Not needed earlier.
- [ ] Sparkle EdDSA key generation + appcast hosting decision (likely the
  GitHub release itself) — required before M4's Sparkle work.
- [ ] App icon refresh — currently a script-generated placeholder; defer
  until M4's polish phase so we don't repaint twice.
