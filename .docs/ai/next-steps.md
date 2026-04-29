# Next Steps

> Short checklist of exact next actions. Updated at end of every session.

## Immediate

- [ ] **M4a Phase B.1** *(user action)* — at appleid.apple.com generate an
  app-specific password labeled `layerkeys-notarytool`. Then run:
  ```bash
  xcrun notarytool store-credentials layerkeys-notarytool \
    --apple-id <your-apple-id> \
    --team-id K7CBQW6MPG \
    --password <app-specific-password>
  ```
  This unblocks Phase B.3 (a real notarized local build) and Phase D.2
  (provisioning the same creds as GitHub Actions secrets).

- [ ] **M4a Phase B.3** — after B.1, run
  `./scripts/package_release.sh` end-to-end and confirm
  `xcrun stapler validate` + `spctl --assess --type execute -vv` both
  show "accepted" and "notarized". This is the real verification that
  the signing path works for distribution.

## Soon

- [ ] **M4a Phase D.1** — `gh repo create TaylorFinklea/layerkeys --public
  --source . --push`. (Decision: probably public from day one because the
  cask URL is already public-facing. Confirm before running.)
- [ ] **M4a Phase D.2** — provision GitHub Actions secrets via
  `gh secret set`:
  - `APPLE_DEVID_CERT_P12_BASE64` (`security export -k login.keychain
    -t identities -f pkcs12 -o /tmp/cert.p12 ...` → `base64 < /tmp/cert.p12`)
  - `APPLE_DEVID_CERT_PASSWORD` (the password you used during the export)
  - `NOTARY_APPLE_ID`, `NOTARY_PASSWORD`, `NOTARY_TEAM_ID=K7CBQW6MPG`
  - `SPARKLE_EDDSA_PRIVATE_KEY` (`/tmp/sparkle-cli/bin/generate_keys -x
    -` to dump the private key to stdout)
- [ ] **M4a Phase D.3** — update `.github/workflows/release.yml` with the
  cert-import-from-secrets step, the notarytool submit step (Apple-ID
  creds path), and a `generate_appcast` step that uploads `appcast.xml`
  alongside `LayerKeys.zip`.
- [ ] **M4a Phase E** — bump `MARKETING_VERSION` to `0.2.0`, regenerate
  xcodeproj, commit, tag `v0.2.0`, push tag, watch CI, then run
  `./scripts/update_homebrew_tap.sh` and push the tap repo.
- [ ] **M4a Phase F.1** — strip the `xattr -dr com.apple.quarantine`
  instruction from README; add a one-line "auto-updates via Sparkle"
  blurb in the install section.
- [ ] Visual smoke test of Phase A (Settings "General" tab, first-launch
  prompt, Check-for-Updates button in menu-bar) — open a debug build
  manually before tagging `v0.2.0`. Don't let CI ship a UI you've never
  seen.

## Deferred

- [ ] Backlog Sonnet-tier: extract the duplicated
  `add/remove/update*Binding` methods in `AppModel` into a generic over
  a `WritableKeyPath`. Good pre-M4b warmup once 0.2.0 is out.
- [ ] Backlog Haiku-tier: `MappingStore.swift` `try? save(.default)`
  silently swallows the migration save error. Route through the
  existing `lastError` plumbing.
- [ ] **M4b** items (post-0.2.0 ship): full first-run onboarding wizard,
  conflict warnings in binding editor, hand-designed app icon refresh,
  marketing pass (README screenshots + GIF), non-US keyboard-layout
  glyph labels (deferred from M3), version bump to `1.0.0`.
- [ ] Backlog Opus-tier: investigate replacing `Thread` + `CFRunLoop`
  with a `DispatchQueue` / actor-wrapped `CFRunLoop`. Not until after
  M4b ships. Only pursue if a latency regression study shows it's worth
  the churn.
- [ ] "Advanced triggers" milestone (post-M4b): F-keys as triggers,
  CapsLock-as-trigger with remap-in-System-Settings help text,
  modifier-only triggers with left/right distinction. See
  `decisions.md` 2026-04-20 entry.
- [ ] Function keys as *targets* (not sources / not triggers). Still
  explicitly not a milestone. Revisit only if a real user asks.
