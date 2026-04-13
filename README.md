# LayerKeys

LayerKeys is a macOS menu bar app for navigation and numpad layers without kernel extensions or Karabiner-style configuration.

## Current defaults

- Hold `Control+Space` to enter the navigation layer.
- Tap `Control+Space` to emit a normal `Escape`.
- While the navigation layer is active, press `A` to switch into the numpad layer until `Space` is released.
- Default nav bindings: `H/J/K/L` to arrows.
- Default numpad bindings: `U/I/O`, `J/K/L`, `M/,/.` to keypad digits.

## Install

Install from the Homebrew tap:

```bash
brew install --cask TaylorFinklea/tap/layerkeys
```

If Gatekeeper blocks launch because the app is not notarized yet:

```bash
xattr -dr com.apple.quarantine "/Applications/LayerKeys.app"
```

## Permissions

LayerKeys needs:

- `Input Monitoring` to intercept global key events and remap them.
- `Accessibility` only if you want tap `Control+Space` to replay a normal `Escape`.

Without Accessibility, the layer behavior still works, but tap-to-escape replay is disabled.

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

The repo includes a GitHub Actions workflow that builds `LayerKeys.zip` on every `v*` tag and uploads it to a GitHub release. The Homebrew cask is written to expect this asset URL:

`https://github.com/TaylorFinklea/layerkeys/releases/download/v<version>/LayerKeys.zip`

Suggested release flow:

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
2. Run `./scripts/package_release.sh`.
3. Run `./scripts/update_homebrew_tap.sh`.
4. Commit both repos.
5. Tag the app repo with `v<version>`.
6. Push the app repo, tag, and tap repo.

## Project status

- License: MIT
- Target platform: macOS 14+
- Distribution: Homebrew cask + zipped app release

