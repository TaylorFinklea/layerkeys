# Next Steps

> Short checklist of exact next actions. Updated at end of every session.

## Immediate

- [ ] Plan **M4: Notarized v1.0** — the shipping milestone. Front-load
  the external-dependency checklist: confirm the Apple Developer ID
  cert is in the local login keychain, stand up the GitHub Actions
  secrets for `notarytool` (Apple ID, app-specific password, team ID),
  generate the Sparkle EdDSA keypair, and pick where the appcast XML
  will live (likely the GitHub release itself, same URL pattern as the
  current `LayerKeys.zip`). Only after those are in place does the
  `scripts/package_release.sh` / `release.yml` work make sense.

## Soon

- [ ] Backlog Sonnet-tier: extract the duplicated
  `add/remove/update*Binding` methods in `AppModel` into a generic over
  a `WritableKeyPath`. Good pre-M4 warmup — shrinks `AppModel` before
  the onboarding work adds more code there.
- [ ] Backlog Haiku-tier: `MappingStore.swift` `try? save(.default)`
  silently swallows the migration save error. Route through the
  existing `lastError` plumbing.

## Deferred

- [ ] "Advanced triggers" milestone (post-M4 at the earliest): F-keys
  as triggers, CapsLock-as-trigger with remap-in-System-Settings help
  text, modifier-only triggers with left/right distinction via NSEvent
  device-dependent flags. See `decisions.md` 2026-04-20 entry.
- [ ] Non-US keyboard-layout glyph labels in the Settings pickers.
  Deferred from M3; fold into M4 polish or a later localization
  milestone. Carbon/TIS glue (`TISCopyCurrentKeyboardInputSource` +
  `UCKeyTranslate`) is the documented path. Keycodes are already
  layout-independent — this is purely UI text.
- [ ] Backlog Opus-tier: investigate replacing `Thread` + `CFRunLoop`
  with a `DispatchQueue` / actor-wrapped `CFRunLoop`. Not until after
  M4 ships. Only pursue if a latency regression study shows it's worth
  the churn.
- [ ] Function keys as *targets* (not sources / not triggers). Still
  explicitly not a milestone. Revisit only if a real user asks.
