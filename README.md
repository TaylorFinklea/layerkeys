# LayerKeys

LayerKeys is a macOS menu bar app for navigation and numpad layers without kernel extensions or Karabiner-style configuration.

## Defaults

Out of the box:

- Hold `Control+Space` to enter the navigation layer.
- Tap `Control+Space` to emit a normal `Escape`.
- While the navigation layer is active, press `A` to switch into the numpad layer until the trigger is released.
- Nav bindings: `H/J/K/L` to arrows.
- Numpad bindings: `U/I/O`, `J/K/L`, `M/,/.` to keypad digits.

Everything is configurable in **Settings → Triggers** and **Settings → Mappings**: pick a different layer trigger chord (any `⌘ ⌃ ⌥ ⇧` combination plus any typing-cluster key), change the numpad sub-trigger, toggle tap-to-Escape, and edit which source keys emit which arrow / keypad keys.

## Install

Install from the Homebrew tap:

```bash
brew install --cask TaylorFinklea/tap/layerkeys
```

The cask installs a Developer-ID-signed and Apple-notarized build, so macOS opens it without a Gatekeeper prompt. After install, LayerKeys auto-updates via Sparkle — new versions show up in-app under **Check for Updates…** (menu bar dropdown and Settings → General).

## Permissions

LayerKeys needs:

- `Input Monitoring` to intercept global key events and remap them.
- `Accessibility` only if you want tap-trigger to replay a normal `Escape`.

Without Accessibility, the layer behavior still works, but tap-to-Escape replay is disabled.

## Build locally

```bash
xcodebuild test -scheme LayerKeys -project LayerKeys.xcodeproj -destination 'platform=macOS'
xcodebuild build -scheme LayerKeys -project LayerKeys.xcodeproj -configuration Release -destination 'platform=macOS'
```

## Release workflow

### Local release packaging

Build the distributable zip and print the checksum:

```bash
./scripts/package_release.sh
```

That writes:

- `dist/LayerKeys.zip`
- `dist/LayerKeys.sha256`

### Update the Homebrew tap

After packaging a release zip:

```bash
./scripts/update_homebrew_tap.sh
```

That rewrites the cask in the sibling tap repo at `../homebrew-tap`.

### GitHub release

The repo includes a GitHub Actions workflow that, on every `v*` tag, runs the test suite, signs + notarizes `LayerKeys.app`, generates a Sparkle `appcast.xml`, and uploads both artifacts to the GitHub release. The Homebrew cask expects:

`https://github.com/TaylorFinklea/layerkeys/releases/download/v<version>/LayerKeys.zip`

…and Sparkle pulls the appcast from `releases/latest/download/appcast.xml`.

Suggested release flow:

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
2. Commit, tag the app repo with `v<version>`, push the tag → CI cuts the release.
3. Run `./scripts/update_homebrew_tap.sh` once the release is published, then commit and push the tap repo.

## Project status

- License: MIT
- Target platform: macOS 14+
- Distribution: Homebrew cask + zipped app release

