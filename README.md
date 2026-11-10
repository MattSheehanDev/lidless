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
```

## Releasing

Releases are automatic. Every push to `main` runs the [Release workflow](.github/workflows/release.yml), which runs the tests and then [semantic-release](https://semantic-release.gitbook.io). semantic-release reads the [Conventional Commits](https://www.conventionalcommits.org) since the last `v*` tag and picks the next version:

| Commit message | Release |
|---|---|
| `fix: countdown skips a second` or `perf: …` | Patch, e.g. 1.1.0 → 1.1.1 |
| `feat: add a 24-hour preset` | Minor, e.g. 1.1.0 → 1.2.0 |
| `feat!: require macOS 15`, or a `BREAKING CHANGE:` footer | Major, e.g. 1.1.0 → 2.0.0 |
| `docs:`, `chore:`, `ci:`, `test:`, `refactor:`, `style:`, `build:` | No release |

When a release is due, it builds a universal `Lidless.zip`, tags `v<version>`, and publishes a GitHub release with the zip attached and notes grouped by commit type. The download link above always gets the newest release.

Commits that don't follow the format are ignored, so a typo like `feature:` won't release. To preview the next version without publishing, run the workflow manually from the Actions tab; that does a dry run.

`make app` builds the release binary with SwiftPM and wraps it in an ad-hoc signed `.app` bundle (see `scripts/bundle.sh`). The app runs as a menu bar–only agent (`LSUIElement`), so it has no Dock icon.

Use `make test` rather than plain `swift test`: with only the Command Line Tools installed, incremental rebuilds lose the Swift Testing macro plugin, and the Makefile passes its path explicitly.

## Preferences

Open **Preferences…** (⌘,) from the menu:

- **Launch at login** — registers the app as a login item. Works best once installed in `/Applications`.
- **Allow display to sleep** — the screen may turn off, but the Mac itself stays awake.
- **Keep awake with lid closed** — also available directly in the menu. See below.

## Keep awake with the lid closed

macOS ignores normal keep-awake requests when you close the lid. The only switch that stops lid-close sleep is the system-wide `pmset disablesleep` setting, which needs root. When you first turn this mode on, Lidless asks for your administrator password once and installs `/etc/sudoers.d/lidless`, which lets your account run exactly these two commands without a password:

```
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
```

With the mode on, Lidless disables sleep only while a session is running. While it's active, the menu header ends with ", even with lid closed". Sleep is turned back on when:

- the session's time runs out, or you choose **Turn Off**;
- you quit Lidless, including with `kill`, `killall Lidless`, or at logout;
- on battery power, the charge drops to 10%.

It also protects against leaving sleep disabled by accident:

- If Lidless is force-killed (`kill -9`) or crashes mid-session, it re-enables sleep the next time it launches.
- If you had already run `pmset disablesleep 1` yourself, Lidless leaves the setting alone.

To check the current state from Terminal:

```bash
pmset -g | grep SleepDisabled      # 1 while a lid-closed session is running
pmset -g log | grep -E "Sleep  |Wake  "   # sleep and wake history, to confirm the Mac stayed awake
```

While sleep is disabled, the Mac also won't sleep from **Apple menu → Sleep**. Running with the lid closed in a bag can get hot, so give it some airflow.

To remove the rule, use **Remove Lid-Closed Helper…** in Preferences, or run `sudo rm /etc/sudoers.d/lidless`. If sleep is ever stuck off, `sudo pmset -a disablesleep 0` restores it.

## Command-line flags

Start a session at launch, handy for scripts:

```bash
open /Applications/Lidless.app --args --minutes 45
open /Applications/Lidless.app --args --indefinite
```

## How it works

Lidless holds an IOKit power assertion (the same mechanism as `caffeinate`) while a session is active. This prevents idle sleep only:

- `PreventUserIdleDisplaySleep` by default
- `PreventUserIdleSystemSleep` when **Allow display to sleep** is on

The assertion is released when the session ends, when you choose **Turn Off**, or when the app quits. You can see it with:

```bash
pmset -g assertions | grep Lidless
```

## Limitations

- **Closing the lid still sleeps the Mac** unless you turn on [Keep awake with lid closed](#keep-awake-with-the-lid-closed), which needs a one-time administrator password.
- The app is ad-hoc signed, not notarized, so the first launch needs **Open Anyway** (see [Install](#install)).

## Project layout

```
Sources/LidlessCore/   AwakeController, power assertions, lid-closed mode, battery checks, launch flags, preferences
Sources/Lidless/       Menu bar UI (AppDelegate) and Preferences window
Tests/LidlessCoreTests Swift Testing suite with a fake clock and fake power assertions
scripts/bundle.sh      Builds and packages Lidless.app
scripts/package.sh     Builds the universal app and Lidless.zip
.releaserc.json        semantic-release configuration
.github/workflows/     Release workflow
```

## Website

Project page: https://mattsheehandev.github.io/lidless/ (served by GitHub Pages from `docs/`).
