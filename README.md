<div align="center">

# SlamX

**Sensor-only MacBook impact detection with local sound feedback.**

[![Release](https://img.shields.io/github/v/release/jx-grxf/SlamX?label=release)](https://github.com/jx-grxf/SlamX/releases)
[![CI](https://github.com/jx-grxf/SlamX/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/jx-grxf/SlamX/actions/workflows/ci.yml)
![Status](https://img.shields.io/badge/status-technical%20preview-f59e0b)
![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-native%20macOS-0A84FF)
![Sparkle](https://img.shields.io/badge/Sparkle-2-0A84FF)
![Detection](https://img.shields.io/badge/detection-sensor--only-16a34a)
![Platform](https://img.shields.io/badge/platform-macOS%2014+-111827)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

</div>

SlamX is an experimental native macOS utility that reads the built-in Apple SPU accelerometer, detects sharp impact spikes, increments a counter, and plays local sound feedback.

Motion data stays on the Mac. SlamX does not use the microphone, does not request microphone access, and does not provide audio-based fallback detection for unsupported Macs.

> SlamX is a technical preview for supported MacBooks. Use light taps for calibration and testing; Johannes is not responsible for hardware damage caused by excessive force.

---

## Showcase

<p align="center">
  <img src="docs/showcase/slamx.png" alt="SlamX app artwork" width="180">
</p>

| Onboarding | Calibration | Live Dashboard |
|---|---|---|
| <img src="docs/showcase/monitor-slamx.jpeg" alt="SlamX onboarding availability check"> | <img src="docs/showcase/monitor-calibration.jpeg" alt="SlamX calibration threshold screen"> | <img src="docs/showcase/monitor-dash.jpeg" alt="SlamX live dashboard telemetry"> |

---

## Contents

- [SlamX](#slamx)
  - [Showcase](#showcase)
  - [Contents](#contents)
  - [Highlights](#highlights)
  - [Compatibility](#compatibility)
  - [Why This Exists](#why-this-exists)
  - [Current Workflow](#current-workflow)
  - [Tech Stack](#tech-stack)
  - [Requirements](#requirements)
  - [Quick Start](#quick-start)
  - [Usage](#usage)
  - [Privacy \& Trust](#privacy--trust)
  - [Release \& Distribution Status](#release--distribution-status)
  - [CI \& Repository Health](#ci--repository-health)
  - [Development](#development)
  - [Research Notes](#research-notes)
  - [Roadmap](#roadmap)
  - [License](#license)

---

## Highlights

| Feature | Description |
|---|---|
| Native macOS app | SwiftUI app with `NavigationSplitView`, `Settings`, menu commands, and a menu bar extra |
| Apple SPU sensor stream | Reads MacBook accelerometer reports from `AppleSPUHIDDevice` through IOKit HID |
| Live telemetry | Shows event count, current impact, peak impact, sample rate, axes, magnitude, and raw HID bytes |
| Guided calibration | Threshold slider, Soft/Balanced/Hard presets, and a two-step calibration wizard |
| Local sound feedback | Bundled sounds plus optional local MP3 imports copied into Application Support |
| macOS utility controls | Menu bar controls, launch-at-login support, persisted counter and threshold, and global mute |
| Sparkle updates | Public appcast support for release assets hosted on GitHub |
| Testable core | `SlamXCore` isolates report parsing and impact detection behind XCTest coverage |

## Compatibility

| Mac | Status | Notes |
|---|---|---|
| Apple Silicon MacBook with accessible Apple SPU accelerometer | Supported | Intended target for live detection |
| Intel MacBook | Unknown | Depends on whether the expected HID device is exposed |
| iMac, Mac mini, Mac Studio, Mac Pro | Unsupported | No MacBook motion sensor for SlamX to read |
| Macs without accessible `AppleSPUHIDDevice` | Unsupported | SlamX intentionally has no microphone fallback |

Unsupported Mac means unsupported live detection. SlamX is sensor-only by design.

---

## Why This Exists

MacBooks contain internal motion hardware, but Apple does not expose a clean public Core Motion API for MacBook accelerometer data. The practical route for this experiment is the HID stream exposed by `AppleSPUHIDDevice`.

SlamX wraps that low-level stream in a small native app with visible telemetry, calibration, and local audio feedback so tuning is observable instead of guesswork.

The stable app path uses direct local HID access. Historical or pre-release admin-helper builds may exist for compatibility experiments, but they are not the normal stable-flow expectation.

## Current Workflow

1. Start SlamX.
2. Complete the sensor availability check.
3. Verify live detection with one light tap during onboarding.
4. Open the monitor and start listening from the toolbar, menu bar, or `Command-R`.
5. Watch live impact, peak, sample rate, axes, and raw report telemetry.
6. Tune the threshold manually or use the calibration wizard.
7. Select a bundled or custom local sound.

If no accessible Apple SPU accelerometer is found, SlamX explains that the Mac is unsupported and blocks live detection.

---

## Tech Stack

| Layer | Technologies |
|---|---|
| Language | Swift 6 project settings and Swift Package tools 6.0 |
| UI | SwiftUI, Observation |
| Sensor access | IOKit HID, `AppleSPUHIDDevice` |
| Audio | AVFoundation |
| App updates | Sparkle 2 |
| macOS services | AppKit, Carbon hot key, ServiceManagement launch-at-login |
| Package | Swift Package Manager plus native Xcode project |
| Tests | XCTest |

## Requirements

- macOS 14 or newer
- Supported MacBook with an accessible Apple SPU accelerometer
- Xcode for app packaging through `SlamX.xcodeproj`
- Swift 6 compatible toolchain for package builds and tests
- Node.js/npm available for DMG generation through `npx create-dmg`

---

## Quick Start

Run tests:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Run the app from SwiftPM:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run SlamX
```

Open the native Xcode project for signing, app icon work, archives, and normal macOS app development:

```bash
open SlamX.xcodeproj
```

Build a local `.app` bundle:

```bash
./scripts/package-app.sh <version> <build-number>
open .build/xcode-release/Release/SlamX.app
```

Example:

```bash
./scripts/package-app.sh 0.3.4 8
```

## Usage

- On first launch, complete the availability check and sound-test onboarding with one light tap.
- Start or stop monitoring from the toolbar, menu bar extra, or `Command-R`.
- Use the threshold slider or calibration wizard to tune detection.
- Choose `Slap`, `Air Pop`, `Alert`, or `Snap`; enable bonus sounds in Settings to unlock `Spotlight`.
- Add custom MP3 files from the Monitor sound control, then select or remove them from the Custom MP3s menu.
- Use `Command-T` to test the selected sound.
- Use `Command-Shift-M` to mute or unmute sounds globally.
- Use `Command-0` to reset the counter.
- Use `Command-U` to check for updates.

---

## Privacy & Trust

- SlamX reads local Apple SPU accelerometer reports through IOKit.
- SlamX is sensor-only and does not request microphone access.
- Motion samples, raw HID bytes, counters, thresholds, and selected sounds are not uploaded.
- Custom MP3 files are copied into local Application Support storage only after the user chooses them.
- Sparkle contacts the public update feed configured in `Resources/Info.plist`.
- Unsupported Macs do not fall back to microphone or audio-based detection.

## Release & Distribution Status

SlamX is public-source friendly and publishes release assets, but it is still a technical preview until Developer ID signing and notarization are in place.

| Release area | Current status |
|---|---|
| Public source | Available in this repository |
| Release assets | DMG, SHA256 checksum, Sparkle appcast, release notes HTML, source `.zip`, source `.tar.gz` |
| Sparkle updates | Supported through public GitHub release assets |
| Release notes | Intentionally curated by hand for public releases; generated commit-list notes are only a fallback |
| Developer ID signing | Planned |
| Notarization and stapling | Planned |
| Gatekeeper UX | Local/ad-hoc builds may show macOS security warnings |

Create the full local release asset set:

```bash
./scripts/create-release-assets.sh <version> <build-number>
```

Use curated human release notes when preparing a public release:

```bash
RELEASE_NOTES_FILE=/path/to/release-notes.html ./scripts/create-release-assets.sh <version> <build-number>
```

For a release tag that differs from the numeric app version:

```bash
RELEASE_TAG=v0.3.4-fix ./scripts/create-release-assets.sh 0.3.4 8
```

Upload these generated assets for a complete release:

| Asset | Purpose |
|---|---|
| `SlamX-<version>.dmg` | App installer image |
| `SlamX-<version>.dmg.sha256` | Checksum for manual verification |
| `appcast.xml` | Sparkle update feed |
| `SlamX-<version>.html` | Release notes embedded into Sparkle |
| `SlamX-<version>-source.zip` | Source archive |
| `SlamX-<version>-source.tar.gz` | Source archive |

Do not present a local DMG as a polished public binary until it is Developer-ID signed, notarized, stapled, and tested on a Gatekeeper-enabled Mac.

## CI & Repository Health

| Area | Current coverage |
|---|---|
| Unit tests | GitHub Actions runs `swift test` |
| Secret scanning | Gitleaks runs in CI |
| Dependency scanning | OSV Scanner runs in CI |
| Dependency updates | Dependabot tracks GitHub Actions and Swift packages |
| Release automation | Local scripts exist; release CI and upload automation are planned |
| App build smoke test | Planned: add `xcodebuild` CI coverage for the native macOS project |

Current CI is intentionally small but useful: it protects the testable Swift core, scans for leaked secrets, scans dependency risk, and keeps dependencies visible.

---

## Development

Run the test suite:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Run the app in debug mode:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run SlamX
```

Build through Xcode:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SlamX.xcodeproj \
  -scheme SlamX \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Package a local release app:

```bash
./scripts/package-app.sh <version> <build-number>
```

Build a local DMG and checksum:

```bash
./scripts/create-dmg.sh <version> <build-number>
```

Generate a Sparkle appcast from existing DMG assets:

```bash
./scripts/generate-appcast.sh .build/dmg
```

Prepare the full release asset set:

```bash
./scripts/create-release-assets.sh <version> <build-number>
```

Detailed Sparkle release notes live in [`docs/sparkle-updates.md`](docs/sparkle-updates.md).

---

## Research Notes

- Apple documents Core Motion primarily for platforms with a public `CMMotionManager` path, but that is not the MacBook accelerometer interface SlamX uses.
- Apple documents the HID APIs used here through IOKit, including [`IOHIDDeviceRegisterInputReportCallback`](https://developer.apple.com/documentation/iokit/1588666-iohiddeviceregisterinputreportca).
- The local IORegistry exposes the relevant MacBook stream as `AppleSPUHIDDevice` with usage page `0xFF00` and usage `0x03`.
- Recent Apple SPU drivers may need driver/reporting state to be awake before accelerometer reports appear.
- The parser stays isolated because Apple can change private report layout details between hardware generations.

## Roadmap

| Status | Item |
|---|---|
| Planned | Developer ID signing, notarization, and stapling |
| Planned | Release CI for native app build and asset smoke checks |
| Planned | Appcast validation before release upload |
| Planned | Better unsupported-Mac diagnostics |
| Planned | Hardware compatibility matrix from tested MacBook models |
| Later | Calibration profile export/import |

---

## License

MIT
