# Current State

> Updated at the end of every work session. Read this first.

## Active Branch

`main`

## Last Session Summary

**Date**: 2026-04-18

- Bootstrapped `.docs/ai/` (this directory) for cross-session continuity per
  the global Claude Code workflow.
- Wrote `CLAUDE.md` documenting build/test/release commands, the
  MenuBar → AppModel → EventTapService → LayerStateMachine → KeyCatalog
  → PermissionController architecture, and the event-tap invariants future
  sessions must preserve. Committed as `ff8386d`.
- Captured product direction with the user: minimalist nav+numpad identity,
  capability-first milestone sequencing (M1 source-key catalog → M2
  configurable trigger → M3 reliability → M4 notarized v1.0), Apple
  Developer ID available for notarization, Homebrew-only install with
  Sparkle in-app updates, fully-offline no-telemetry stance, numpad
  falling back to nav (current behavior) preserved, `tier3_owner: claude`.
- Wrote `roadmap.md` with milestones M1–M4, a seeded Backlog (1 Haiku,
  3 Sonnet, 2 Opus), priority order, and constraints.
- No code changes outside `CLAUDE.md`.

## Build Status

- App: not rebuilt this session (no source changes touched).
- Tests: not re-run this session; last known state from `f3f6958` is green
  on `macos-latest` per `.github/workflows/ci.yml`.
- Release: `0.1.0`, distributed via `TaylorFinklea/tap` Homebrew cask;
  unsigned/un-notarized (M4 will fix).

## Blockers

- None. Next session is plan-mode for the M1 phase.
