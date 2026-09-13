# Prevent Sleep ☕️

A lightweight, native macOS menu-bar switch controlling your Mac's persistent `SleepDisabled` power setting.

Replace repetitive authenticated Terminal commands (`sudo pmset disablesleep 1`) with an instant, reliable menu-bar toggle that reflects true system state.

---

## Features

- **One-Click Toggle:** Left-click to switch between Prevent Sleep (ON) and Normal Sleep (OFF).
- **Truthful Status:** Always reflects verified system power settings from `/usr/bin/pmset -g`, not a stale cached preference.
- **No Password Prompts After Setup:** Uses an approved macOS LaunchDaemon (`SMAppService`) so daily clicks are instantaneous.
- **External Change Detection:** Adopts settings changed via Terminal or third-party tools within ~1–2 seconds.
- **Right-Click Options Menu:** Accessible keyboard controls, Setup & Approval status, Launch at Login, and Guided Removal.
- **Safe Guided Removal:** "Allow Sleep & Remove Helper" resets `SleepDisabled` back to 0, confirms readback, and unregisters the helper daemon.

---

## How Everything Connects (For Dummies) 🧠

If you've ever wondered why you can't just click a button in an ordinary Mac app to stop your Mac from sleeping forever without typing your password every time, this section is for you!

### The Problem: macOS Security & The "Root" Wall

1. macOS protects vital hardware and power management settings behind **root permissions** (administrator privileges).
2. Changing whether your Mac is allowed to sleep is done by the system tool `/usr/bin/pmset disablesleep 1` (or `0`).
3. If an ordinary app tried to run that command directly, macOS would block it with **"Permission Denied"**, or pop up an annoying password dialog every single time you clicked the icon.

### The Solution: The Two-Part Architecture

To make the button work with a single click and no recurring password prompts, Prevent Sleep is split into **two distinct programs** working together:

```
+-------------------------------------------------------------------------------+
|                                  YOUR MAC                                     |
|                                                                               |
|  1. You Click the Menu Bar Icon                                               |
|     (cup.and.saucer.fill)                                                     |
|            │                                                                  |
|            ▼                                                                  |
|  +────────────────────────────────────────+                                   |
|  |     PART 1: The Menu Bar App           |  (Unprivileged user app)          |
|  |     - Sits in your menu bar            |  - Has NO special permissions     |
|  |     - Draws the coffee cup icons       |  - Cannot run root commands       |
|  |     - Coordinates UI & clicks          |                                   |
|  +────────────────────────────────────────+                                   |
|            │                                                                  |
|            │  2. Secret Authenticated Handshake (XPC)                         |
|            ▼                                                                  |
|  +────────────────────────────────────────+                                   |
|  |     PART 2: The Privileged Helper      |  (Approved LaunchDaemon)          |
|  |     - Installed in background          |  - Runs with root permissions     |
|  |     - Verifies who is talking to it    |  - ONLY accepts 2 fixed commands: |
|  |       (rejects impostor apps)          |    "What is the setting?"         |
|  |                                        |    "Turn it ON or OFF"            |
|  +────────────────────────────────────────+                                   |
|            │                                                                  |
|            │  3. Runs system command with fixed arguments                     |
|            ▼                                                                  |
|  +────────────────────────────────────────+                                   |
|  |     /usr/bin/pmset disablesleep 1 / 0  |                                   |
|  +────────────────────────────────────────+                                   |
|            │                                                                  |
|            │  4. Changes macOS kernel power setting                           |
|            ▼                                                                  |
|  +────────────────────────────────────────+                                   |
|  |     macOS Power Manager (powerd)       |                                   |
|  |     (SleepDisabled = 1)                |                                   |
|  +────────────────────────────────────────+                                   |
|            │                                                                  |
|            │  5. Immediate Readback Confirmation                              |
|            │     (Helper runs "pmset -g" to double check)                     |
|            ▼                                                                  |
|  +────────────────────────────────────────+                                   |
|  |     Confirmed True State Sent to App   |                                   |
|  +────────────────────────────────────────+                                   |
|            │                                                                  |
|            ▼                                                                  |
|  6. Menu bar icon updates silently to confirmed state!                        |
+-------------------------------------------------------------------------------+
```

### Step-by-Step Walkthrough

1. **The Click:** You left-click the coffee cup in your menu bar. The icon immediately turns into a rotating/busy icon so you know it heard you.
2. **The Handshake (XPC):** The menu-bar app sends a private message across macOS's built-in communication pipe (**XPC**) to the background helper daemon.
3. **The ID Check:** The background helper daemon checks the app's cryptographic code signature. If any unknown software tries to talk to it, the helper immediately hangs up.
4. **The Safe Command:** The helper directly executes `/usr/bin/pmset disablesleep 1` (or `0`). It never uses arbitrary shell scripts or open terminal windows.
5. **The Proof (Readback):** The helper does not assume the command worked just because it didn't crash. It immediately asks macOS (`pmset -g`): *"What is SleepDisabled right now?"*
6. **The Result:** If macOS confirms `SleepDisabled 1`, the helper reports success back to the app. The app silently updates the menu-bar icon to the filled coffee cup.

### Why do I only approve it once in System Settings?

When you first open Prevent Sleep, macOS asks you to approve the background helper once in **System Settings → General → Login Items & Extensions**. 

Once approved by an administrator, macOS remembers your approval permanently across reboots. That is why future toggles are instant and never ask for your password again!

---

## Operational States & Icons

| State | Menu Bar Icon | Tooltip | Meaning |
| --- | :---: | --- | --- |
| **Ready (ON)** | `cup.and.saucer.fill` | Prevent Sleep: On | Sleep is disabled (`SleepDisabled 1`). Mac will stay awake. |
| **Ready (OFF)** | `cup.and.saucer` | Prevent Sleep: Off | Sleep is allowed (`SleepDisabled 0`). Standard power rules apply. |
| **Changing** | `arrow.triangle.2.circlepath` | Changing sleep setting... | Command in flight. Subsequent clicks are safely ignored. |
| **Unavailable** | `exclamationmark.triangle` | Sleep setting unavailable | Read error or helper not reachable. Click to inspect. |
| **Setup Required** | `gearshape.badge.exclamationmark` | Setup required | Helper needs initial approval in System Settings. |

---

## Building and Installing

### Prerequisites

- macOS 26.0+ (Tahoe)
- Xcode 26.0+ (Command Line Tools or Xcode.app)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Build Release App

Run the build script:
```bash
./scripts/build-and-install.sh
```

Or build manually:
```bash
# 1. Generate Xcode project from project.yml
xcodegen generate

# 2. Build Release configuration
xcodebuild -project PreventSleep.xcodeproj -scheme PreventSleep -configuration Release build
```

The resulting `PreventSleep.app` bundle will contain the bundled helper inside:
`PreventSleep.app/Contents/Library/LaunchDaemons/com.sramzz.mac-no-sleep.helper`

Copy `PreventSleep.app` to `/Applications/` to use it.

---

## Running Automated Tests

Run the test suite via Swift Package Manager:
```bash
swift test
```

Or with a specific Xcode developer directory:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

This runs 17 unit tests verifying:
- Strict output parsing (handling edge cases, missing fields, malformed lines).
- State coordination (handling rapid clicks, debounce, stale observation rejection).
- Command execution & readback verification.
- Menu-bar UI icon and accessibility label mapping.

---

## Uninstalling / Resetting

### Method 1: In-App (Recommended)
1. Right-click the menu-bar icon.
2. Select **Allow Sleep & Remove Helper...**.
3. Confirm the dialog. The app will ensure `SleepDisabled` is set to `0`, unregister the background LaunchDaemon, and remove launch at login.
4. Move `PreventSleep.app` to Trash.

### Method 2: Manual Recovery Script
If the app was already deleted or cannot run, execute the provided uninstall script in Terminal:
```bash
./scripts/uninstall-helper.sh
```
This restores your Mac's sleep settings to default (`SleepDisabled 0`) and unregisters the LaunchDaemon.
