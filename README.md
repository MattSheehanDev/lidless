# Lidless

A tiny macOS menu bar app that keeps your Mac awake — indefinitely or for a set amount of time.

Click the cup in the menu bar and pick a duration:

- Indefinitely, 10 / 30 minutes, 1 / 2 / 4 / 8 / 12 hours
- **More → Custom Duration…** for any number of minutes
- **Turn Off** to end a session early

While a session is running the icon fills in and the menu shows a live countdown.

## Install

**[Download Lidless.zip](https://github.com/MattSheehanDev/lidless/releases/latest/download/Lidless.zip)** (macOS 14 or later, Apple Silicon and Intel)

1. Unzip it and move **Lidless.app** to your Applications folder.
2. Open it. macOS blocks it the first time because the app isn't notarized.
3. Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to Lidless.

Or skip steps 2–3 from Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/Lidless.app && open /Applications/Lidless.app
```

All versions are on the [Releases page](https://github.com/MattSheehanDev/lidless/releases).

## Build from source

Requires a Swift 5.10+ toolchain. The Xcode Command Line Tools are enough; full Xcode isn't required.

```bash
make run       # build build/Lidless.app and launch it
make install   # copy to /Applications and launch
make test      # run the test suite
make clean     # remove build output
make package VERSION=1.2.0   # build a universal app and build/Lidless.zip locally
make release VERSION=1.2.0   # tag v1.2.0 and push it, which triggers the release build
```

## Releasing

Run `make release VERSION=1.2.0` from a clean `main`. It runs the tests, then tags `v1.2.0` and pushes the tag. Pushing a `v*` tag triggers the [Release workflow](.github/workflows/release.yml) on GitHub Actions, which tests again, builds a universal `Lidless.zip`, and publishes a GitHub release with it attached. The download link above always gets the newest release.

You can also run the workflow manually from the Actions tab. It tests and packages the app as a downloadable workflow artifact without publishing a release.

`make app` builds the release binary with SwiftPM and wraps it in an ad-hoc signed `.app` bundle (see `scripts/bundle.sh`). The app runs as a menu bar–only agent (`LSUIElement`), so it has no Dock icon.

Use `make test` rather than plain `swift test`: with only the Command Line Tools installed, incremental rebuilds lose the Swift Testing macro plugin, and the Makefile passes its path explicitly.

## Preferences

Open **Preferences…** (⌘,) from the menu:

- **Launch at login** — registers the app as a login item. Works best once installed in `/Applications`.
- **Allow display to sleep** — the screen may turn off, but the Mac itself stays awake.

## Command-line flags

Start a session at launch, handy for scripts:

```bash
open /Applications/Lidless.app --args --minutes 45
open /Applications/Lidless.app --args --indefinite
```

## How it works

Lidless holds an IOKit power assertion (the same mechanism as `caffeinate`) while a session is active:

- `PreventUserIdleDisplaySleep` by default
- `PreventUserIdleSystemSleep` when **Allow display to sleep** is on

The assertion is released when the session ends, when you choose **Turn Off**, or when the app quits. You can see it with:

```bash
pmset -g assertions | grep Lidless
```

## Limitations

- **Closing the lid still sleeps the Mac** unless it's in clamshell mode (external display and power connected). Preventing lid-close sleep requires root (`sudo pmset disablesleep 1`), which Lidless doesn't do.
- The app is ad-hoc signed, not notarized, so the first launch needs **Open Anyway** (see [Install](#install)).

## Project layout

```
Sources/LidlessCore/   AwakeController, power assertions, launch-flag parsing, preferences
Sources/Lidless/       Menu bar UI (AppDelegate) and Preferences window
Tests/LidlessCoreTests Swift Testing suite with a fake clock and fake power assertions
scripts/bundle.sh      Builds and packages Lidless.app
scripts/package.sh     Builds the universal app, Lidless.zip, and release notes
scripts/release.sh     Tags and pushes a version, triggering the Release workflow
.github/workflows/     Release workflow
```

## Website

Project page: https://mattsheehandev.github.io/lidless/ (served by GitHub Pages from `docs/`).
