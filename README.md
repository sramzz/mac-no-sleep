# Prevent Sleep ☕️

[![macOS](https://img.shields.io/badge/macOS-15.0%2B%20%7C%20Tahoe%2026%2B-black?style=flat-square&logo=apple)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square&logo=swift)](https://swift.org)
[![Tests](https://img.shields.io/badge/Tests-19%20passed-brightgreen?style=flat-square)](Tests)
[![Dependencies](https://img.shields.io/badge/Dependencies-0%20(Pure%20Native)-blue?style=flat-square)]()

A lightweight, native macOS menu-bar switch for the Mac's persistent `SleepDisabled` power setting.

Prevent Sleep replaces repetitive authenticated Terminal commands (`sudo pmset disablesleep 1`) with an instantaneous, reliable menu-bar switch that reflects the true kernel power state.

---

## Key Features

- **One-Click Instant Toggle:** Left-click to switch between Prevent Sleep (ON) and Normal Sleep (OFF) in under 0.3 seconds.
- **Truthful System State:** Always reflects verified system power settings from `/usr/bin/pmset -g`, not a stale cached preference.
- **Zero Recurring Password Prompts:** Uses a modern macOS privileged LaunchDaemon (`SMAppService`) so daily clicks require zero authorization dialogs.
- **Always Visible (Position 1 by Default):** Defaults to Position 1 on the far right of the menu bar (directly adjacent to Control Center), ensuring it is never obscured by the MacBook notch or menu bar crowding. Fully supports native <kbd>⌘ Command</kbd>-drag reordering.
- **Headless CLI Controls:** Built-in command-line interface (`--toggle`, `--test-helper`, `--register`, `--unregister`) for automation, Raycast, or Terminal scripts.
- **Professional-Grade Logging Subsystem:** 6 configurable log levels (`none` to `trace`/`full`) with emoji badges, timestamps, terminal formatting, and Apple Unified Logging (`os.Logger`) integration.
- **External Change Detection:** Automatically syncs settings changed externally via Terminal or other power tools within ~1 second.
- **Safe Guided Removal:** Built-in "Allow Sleep & Remove Helper" option that restores normal sleep (`SleepDisabled 0`), confirms kernel readback, and unregisters background services cleanly.

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
|  |     - Polls power state every 1s       |                                   |
|  +────────────────────────────────────────+                                   |
|            │                                                                  |
|            │  2. Authenticated XPC Handshake (Mach Service)                   |
|            ▼                                                                  |
|  +────────────────────────────────────────+                                   |
|  |     PART 2: The Privileged Helper      |  (Managed LaunchDaemon)           |
|  |     - Contents/MacOS/<helper-binary>   |  - Runs as root via launchd       |
|  |     - Validates Client Team ID         |  - Restricted to 2 fixed tasks:   |
|  |       (rejects unauthorized apps)      |    • Read: pmset -g               |
|  |                                        |    • Write: pmset disablesleep    |
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

### Why You Only Authorize It Once
When Prevent Sleep is launched for the first time, macOS prompts for a one-time approval in **System Settings → General → Login Items & Extensions → Allow in Background**. Once authorized, macOS Background Task Management (BTM) persists this permission across reboots, allowing the helper to handle XPC requests seamlessly.

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

## Quick Start

### 1. Build & Install
Ensure you have [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed (`brew install xcodegen`).

```bash
./scripts/build-and-install.sh --install
```
This script automatically:
1. Generates the Xcode project.
2. Compiles the Release build.
3. Signs the app bundle and embedded helper with your Apple Development identity (or ad-hoc if unavailable).
4. Strictly verifies code signatures and hardened runtime flags.
5. Installs the application to `/Applications/PreventSleep.app`.

### 2. Launch the Application
```bash
open /Applications/PreventSleep.app
```

### 3. First-Time Setup (One-Time Approval)
1. On first launch, macOS displays a notification: *"Login Items: 'PreventSleep' was added in the background"*.
2. The **Prevent Sleep Setup** window will appear with instructions.
3. Click **"Open System Settings"** (navigates to **General → Login Items & Extensions**).
4. Under **"Allow in Background"**, toggle **ON** the switch for `PreventSleep`.
5. Return to the Setup window and click **"Retry & Check Approval"**.
6. The status turns **green**, the menu bar icon updates to the coffee cup (`cup.and.saucer`), and toggling is ready to use!

---

## Running in Foreground with Live Debug Logs

To watch every click, state transition, and XPC exchange live in your terminal:

```bash
./scripts/run-debug.sh
```

### Configuring Log Levels
Set the `PREVENT_SLEEP_LOG_LEVEL` environment variable or use command-line flags:

```bash
# Trace (full low-level details including raw XPC connections)
PREVENT_SLEEP_LOG_LEVEL=trace /Applications/PreventSleep.app/Contents/MacOS/PreventSleep

# Debug (useful for general development & troubleshooting)
PREVENT_SLEEP_LOG_LEVEL=debug /Applications/PreventSleep.app/Contents/MacOS/PreventSleep

# Info (default for normal operations)
PREVENT_SLEEP_LOG_LEVEL=info /Applications/PreventSleep.app/Contents/MacOS/PreventSleep

# Quiet / None (silences all terminal log output)
PREVENT_SLEEP_LOG_LEVEL=none /Applications/PreventSleep.app/Contents/MacOS/PreventSleep
```

### Streaming Unified System Logs
Prevent Sleep also mirrors all log entries to Apple's Unified Logging (`os.Logger`):
```bash
/usr/bin/log stream --predicate 'subsystem == "com.sramzz.mac-no-sleep"' --level debug
```

---

## Headless CLI Controls

The installed app binary provides direct command-line switches for automation or integration with Spotlight, Raycast, and Alfred:

```bash
# Toggle sleep state (inverts current state and confirms readback)
/Applications/PreventSleep.app/Contents/MacOS/PreventSleep --toggle

# Test helper connectivity and return current state
/Applications/PreventSleep.app/Contents/MacOS/PreventSleep --test-helper

# Register the background LaunchDaemon via SMAppService
/Applications/PreventSleep.app/Contents/MacOS/PreventSleep --register

# Unregister the background LaunchDaemon
/Applications/PreventSleep.app/Contents/MacOS/PreventSleep --unregister
```

---

## Repository Structure

```text
mac-no-sleep/
├── Package.swift                             # Swift Package Manager manifest
├── project.yml                               # XcodeGen project specification
├── PreventSleep.xcodeproj/                   # Generated Xcode project
├── Sources/
│   ├── PreventSleepCore/                     # Shared models, logging, protocols, and parsers
│   │   ├── AppLogger.swift                   # 6-level structured logging engine
│   │   ├── PowerSettingParser.swift          # Robust /usr/bin/pmset -g output parser
│   │   ├── PreventSleepProtocol.swift        # XPC protocol and error definitions
│   │   └── StateCoordinator.swift            # Thread-safe UI state machine and debounce engine
│   ├── PreventSleepHelper/                   # Privileged LaunchDaemon
│   │   ├── HelperService.swift               # XPC listener and client code signature validator
│   │   ├── PowerSettingExecutor.swift        # Direct pmset executor with readback verification
│   │   ├── com.sramzz.mac-no-sleep.helper.plist # Launchd daemon descriptor
│   │   └── main.swift                        # Helper daemon entry point
│   └── PreventSleepApp/                      # Native Menu Bar Application
│       ├── AppDelegate.swift                 # Application lifecycle, wake observer, SMAppService
│       ├── AppServiceManager.swift           # Wrapper for SMAppService.daemon and login item
│       ├── HelperClient.swift                # Resilient async/await XPC client with timeout handling
│       ├── StatusIconRenderer.swift          # SF Symbol image rendering pipeline
│       ├── StatusItemController.swift        # Menu bar item controller (Position 1 default)
│       ├── SetupView.swift                   # SwiftUI first-time setup window
│       ├── SetupWindowController.swift       # NSWindowController for setup interface
│       └── main.swift                        # App entry point with CLI flag dispatcher
├── Tests/
│   └── PreventSleepCoreTests/                # Comprehensive unit test suite (19 tests)
│       ├── PowerSettingParserTests.swift     # Parsing edge-cases, missing fields, malformations
│       ├── PowerSettingExecutorTests.swift   # Executor readback and failure cases
│       ├── StateCoordinatorTests.swift       # Debounce, race conditions, mutation locking
│       └── StatusIconRendererTests.swift     # SF Symbol mapping, tooltips, and a11y labels
├── scripts/
│   ├── build-and-install.sh                  # Release compilation, signing, and install script
│   ├── run-debug.sh                          # Debug compilation and foreground execution script
│   └── uninstall-helper.sh                   # Clean teardown, reset, and uninstallation script
└── docs/
    ├── implementation-plan.md                # System design and architecture specification
    ├── verification-report.md                # Automated test matrix and signing verification
    └── research/                             # Research on macOS power management and assertions
```

---

## Automated Testing

Run the test suite via Swift Package Manager:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

All 19 tests across 4 test suites execute in **~0.17s** with zero dependencies.

---

## Uninstalling / Resetting

### Method 1: In-App (Recommended)
1. Click (or right-click) the coffee cup menu-bar icon.
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
This resets the power setting to `SleepDisabled 0` and flushes any background daemon registrations.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
