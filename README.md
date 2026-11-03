# Prevent Sleep ☕️

[![macOS](https://img.shields.io/badge/macOS-26.0%2B%20%7C%20Tahoe-black?style=flat-square&logo=apple)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square&logo=swift)](https://swift.org)
[![Tests](https://img.shields.io/badge/Tests-24%20passed-brightgreen?style=flat-square)](Tests)
[![Dependencies](https://img.shields.io/badge/Dependencies-0%20(Pure%20Native)-blue?style=flat-square)]()
[![License](https://img.shields.io/badge/License-Commercial-purple?style=flat-square)](EULA.md)

A lightweight, native macOS menu-bar switch for the Mac's persistent `SleepDisabled` power setting.

Prevent Sleep replaces repetitive authenticated Terminal commands (`sudo pmset disablesleep 1`) with an instantaneous, reliable menu-bar switch that reflects the true kernel power state.

---

## Key Features

- **One-Click Instant Toggle:** Left-click to switch between Prevent Sleep (ON) and Normal Sleep (OFF) in under 0.3 seconds.
- **Truthful System State:** Always reflects verified system power settings from `/usr/bin/pmset -g`, not a stale cached preference.
- **Zero Recurring Password Prompts:** Uses a modern macOS privileged LaunchDaemon (`SMAppService`) so daily clicks require zero authorization dialogs.
- **Low-Battery Auto-Disarm Safeguard:** Automatically disarms sleep prevention and restores normal sleep if your battery falls to or below 15% on battery power, accompanied by a native macOS alert notification.
- **Always Visible (Position 1 by Default):** Defaults to Position 1 on the far right of the menu bar (directly adjacent to Control Center), ensuring it is never obscured by the MacBook notch or menu bar crowding. Fully supports native <kbd>⌘ Command</kbd>-drag reordering.
- **Safe App Quit Warning:** If sleep is currently disabled, quitting prompts you to restore normal sleep with a single click, preventing accidental overnight battery drain.
- **Headless CLI Controls:** Built-in command-line interface (`--toggle`, `--version`, `--test-helper`, `--register`, `--unregister`) for automation, Raycast, or Terminal scripts.
- **Professional-Grade Logging Subsystem:** 6 configurable log levels (`none` to `trace`/`full`) with emoji badges, timestamps, terminal formatting, and Apple Unified Logging (`os.Logger`) integration.
- **Safe Guided Removal:** Built-in "Allow Sleep & Remove Helper" option that restores normal sleep (`SleepDisabled 0`), confirms kernel readback, and unregisters background services cleanly.

---

## Hardware Safety & Thermal Notice

> [!WARNING]
> **Closed-Lid Operation:** When Prevent Sleep is set to **ON**, your Mac will remain fully awake even with the display closed. Do **not** place your laptop inside a closed bag, sleeve, or unventilated container while Prevent Sleep is active, as running active workloads without airflow can cause heat buildup and battery drain. Use the built-in low-battery safeguard and always ensure adequate ventilation.

---

## How It Works (Architecture Overview)

To toggle system power management without recurring password prompts while maintaining strict macOS security, Prevent Sleep is divided into **two specialized native components**:

```text
+-------------------------------------------------------------------------------+
|                                  YOUR MAC                                     |
|                                                                               |
|  1. Left-click Menu Bar Icon (or run --toggle)                                |
|     (cup.and.saucer.fill)                                                     |
|            │                                                                  |
|            ▼                                                                  |
|  +────────────────────────────────────────+                                   |
|  |     PART 1: The Menu Bar App           |  (Unprivileged user app)          |
|  |     - Sits in top menu bar (Position 1)|  - Has NO special root access     |
|  |     - Renders responsive SF Symbols    |  - Coordinates UI & clicks        |
|  |     - BatteryGuard (disarms at <= 15%) |  - Event-driven + coalesced timer |
|  +────────────────────────────────────────+                                   |
|            │                                                                  |
|            │  2. Authenticated XPC Handshake (Mach Service)                   |
|            │     • Cryptographic Audit-Token Validation                       |
|            │     • Team ID Pinning (N4BDK3Z362)                               |
|            ▼                                                                  |
|  +────────────────────────────────────────+                                   |
|  |     PART 2: The Privileged Helper      |  (Managed LaunchDaemon)           |
|  |     - Contents/MacOS/<helper-binary>   |  - Runs as root via launchd       |
|  |     - Validates Client Team ID         |  - Restricted to 3 fixed tasks:   |
|  |       (rejects unauthorized apps)      |    • Read: pmset -g               |
|  |                                        |    • Write: pmset disablesleep    |
|  |                                        |    • Version handshake            |
|  +────────────────────────────────────────+                                   |
|            │                                                                  |
|            │  3. Executes exact command with fixed arguments                  |
|            ▼                                                                  |
|  +────────────────────────────────────────+                                   |
|  |     /usr/bin/pmset disablesleep 1 / 0  |                                   |
|  +────────────────────────────────────────+                                   |
|            │                                                                  |
|            │  4. Updates macOS power manager (powerd)                         |
|            ▼                                                                  |
|  +────────────────────────────────────────+                                   |
|  |     Kernel Power State                 |                                   |
|  |     (SleepDisabled = 1 or 0)           |                                   |
|  +────────────────────────────────────────+                                   |
|            │                                                                  |
|            │  5. Immediate Readback Verification                              |
|            │     (Helper executes "pmset -g" to double-check state)           |
|            ▼                                                                  |
|  +────────────────────────────────────────+                                   |
|  |     Confirmed Power State Replied      |                                   |
|  +────────────────────────────────────────+                                   |
|            │                                                                  |
|            ▼                                                                  |
|  6. Menu bar icon updates instantly to confirmed state (<0.3s)                |
+-------------------------------------------------------------------------------+
```

---

## Operational States & Menu Bar Icons

| State | Menu Bar Icon | Tooltip | Meaning |
| :--- | :---: | :--- | :--- |
| **Ready (ON)** | `cup.and.saucer.fill` | Prevent Sleep: On | Sleep is disabled (`SleepDisabled 1`). Mac will stay awake. |
| **Ready (OFF)** | `cup.and.saucer` | Prevent Sleep: Off | Sleep is allowed (`SleepDisabled 0`). Normal power rules apply. |
| **Changing** | `arrow.triangle.2.circlepath` | Changing sleep setting... | Mutation in flight. Concurrent clicks are safely debounced. |
| **Setup Required** | `gearshape.fill` | Setup required | Helper requires one-time approval in System Settings. |
| **Unavailable** | `exclamationmark.triangle` | Sleep setting unavailable | Read error or helper unreachable. Click opens setup window. |

---

## Quick Start (Build & Install)

Ensure you have [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed (`brew install xcodegen`).

```bash
./scripts/build-and-install.sh --install
```

This script automatically:
1. Generates the Xcode project.
2. Compiles the Release build using a deterministic derived data path.
3. Signs the app bundle and embedded helper with your Apple Development identity (or Developer ID).
4. Strictly verifies code signatures and hardened runtime flags.
5. Installs the application to `/Applications/PreventSleep.app`.

### First-Time Setup (One-Time Approval)
1. On first launch, macOS displays a notification: *"Login Items: 'Prevent Sleep' was added in the background"*.
2. The **Prevent Sleep Setup** window will appear.
3. Click **"Open Login Items Settings"** (navigates to **General → Login Items & Extensions**).
4. Under **"Allow in Background"**, toggle **ON** the switch for `Prevent Sleep`.
5. The window auto-detects approval in real time, displays the closed-lid safety notice, and activates the menu bar icon!

---

## Headless CLI Controls

The installed app binary provides direct command-line switches for automation or integration with Raycast, Alfred, and Shortcuts:

```bash
# Toggle sleep state (inverts current state and confirms readback)
/Applications/PreventSleep.app/Contents/MacOS/PreventSleep --toggle

# Test helper connectivity and return current state
/Applications/PreventSleep.app/Contents/MacOS/PreventSleep --test-helper

# Inspect app and helper version info
/Applications/PreventSleep.app/Contents/MacOS/PreventSleep --version

# Register the background LaunchDaemon via SMAppService
/Applications/PreventSleep.app/Contents/MacOS/PreventSleep --register

# Unregister the background LaunchDaemon
/Applications/PreventSleep.app/Contents/MacOS/PreventSleep --unregister
```

---

## Automated Testing

Run the test suite via Swift Package Manager:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

All 24 tests across 5 test suites execute in **~0.17s** with zero dependencies.

---

## Packaging & Releases

To compile and package a ready-to-distribute `.dmg` disk image:

```bash
# Package DMG signed with local or Developer ID identity:
./scripts/package-dmg.sh

# Complete one-command release with automated testing and SHA-256 checksums:
./scripts/release.sh 1.0.0 100
```

---

## Uninstalling / Resetting

### Method 1: In-App (Recommended)
1. Click the coffee cup menu-bar icon.
2. Select **Allow Sleep & Remove Helper...**.
3. Confirm the alert. Prevent Sleep will:
   - Revert the power setting to normal sleep (`SleepDisabled 0`).
   - Unregister the privileged LaunchDaemon from `smd` and `launchd`.
   - Remove launch-at-login.
4. Move `PreventSleep.app` from `/Applications` to Trash.

### Method 2: Manual Recovery Script
If the application was already moved to Trash or cannot be opened, run the recovery script:
```bash
./scripts/uninstall-helper.sh
```

---

## License

Commercial Proprietary License. Copyright © 2026 Santiago Ramirez. All rights reserved.  
See [EULA.md](EULA.md) for full terms.
