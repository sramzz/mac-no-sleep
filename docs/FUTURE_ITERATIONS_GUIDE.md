# Prevent Sleep — Engineering Philosophy & Future Iteration Guide

**Version:** 1.0.0  
**Last Updated:** November 2026  
**Target:** macOS 26.0+ (Tahoe and later) · Apple Silicon (`arm64`)  
**Commercial Identifiers:**  
- Main App: `com.preventsleep.app`
- Privileged Helper: `com.preventsleep.helper`
- Developer Team ID: `N4BDK3Z362` (`Santiago Ramirez Castano`)

---

## 1. Core Engineering Philosophy

Any engineer or agent working on this codebase in future iterations must honor these five non-negotiable principles:

### Principle 1: Truth Over Assumptions (Kernel as Single Source of Truth)
* **Never cache power state in `UserDefaults` or memory as truth.** 
* When the user clicks the menu bar icon, Prevent Sleep requests the privileged helper to execute `/usr/bin/pmset disablesleep <0|1>`, and **must immediately read back `/usr/bin/pmset -g`** to confirm that the macOS kernel actually accepted the change.
* If the readback does not match the requested target, the app transitions to `.unavailable` or reverts to the true kernel state. We never lie to the user about their system's actual sleep state.

### Principle 2: Zero Recurring User Friction
* Running `sudo pmset disablesleep 1` in Terminal requires entering an administrator password every single time.
* Prevent Sleep uses Apple's modern `SMAppService.daemon` API. During first launch, the user approves the helper **once** in macOS System Settings.
* After that single approval, **every toggle must be instantaneous (<0.3s) with zero authorization dialogs**.

### Principle 3: Strict Cryptographic Defense & Mutual Verification
* The privileged helper runs as a LaunchDaemon with `root` privileges. **Its attack surface must remain microscopic.**
* The helper **never** accepts arbitrary shell strings or arbitrary paths. It only responds to three typed XPC methods:
  1. `getState(withReply:)`
  2. `setPreventSleep(_:withReply:)`
  3. `getVersion(withReply:)`
* **Mutual Audit-Token Verification:** The helper validates the caller's kernel audit token before accepting any connection:
  ```swift
  connection.setCodeSigningRequirement(PreventSleepSecurity.clientRequirement)
  ```
  This requires the Apple cryptographic anchor, the bundle identifier `com.preventsleep.app`, and developer Team ID `N4BDK3Z362`. Rogue processes on the user's Mac cannot communicate with the daemon.

### Principle 4: Humane Hardware Safeguards
* **Low-Battery Auto-Disarm:** If the Mac is running on battery power and falls to $\le 15\%$, `BatteryGuard` and `BatteryMonitor` automatically disarm sleep prevention (`SleepDisabled 0`) and post a native notification to prevent the laptop from dying unexpectedly.
* **Quit Confirmation:** If the user quits the app while sleep is still disabled, an alert prompts: *"Would you like to restore normal sleep before quitting?"* with a one-click *"Allow Sleep & Quit"* action.
* **Thermal Advisory:** Onboarding clearly warns that running heavy workloads with the lid closed inside a bag/backpack can cause overheating.

### Principle 5: Absolute User Privacy (Zero Telemetry)
* Prevent Sleep is a **100% offline utility**.
* No analytics SDKs, no trackers, no crash reporting beacons, no ads.
* All logs are kept local via Apple Unified Logging (`os.Logger`).
* The app contains zero user-identifying paths or hardcoded personal credentials.

---

## 2. Codebase Architecture Map

The project is structured into three clear SPM/Xcode targets:

```text
mac-no-sleep/
├── Sources/
│   ├── PreventSleepCore/        # SHARED BUSINESS LOGIC & PROTOCOLS
│   │   ├── BuildInfo.swift      # Centralized identifiers, Team ID & versions
│   │   ├── BatteryGuard.swift   # Pure logic for battery thresholds (unit tested)
│   │   ├── StateCoordinator.swift # UI state machine & debounce logic
│   │   ├── PowerSettingParser.swift # Pure string parser for pmset output
│   │   ├── AppLogger.swift      # Unified Logging wrapper (6 levels)
│   │   └── PreventSleepProtocol.swift # Shared XPC protocol definition
│   │
│   ├── PreventSleepHelper/      # PRIVILEGED DAEMON (ROOT)
│   │   ├── HelperService.swift  # XPC listener with audit-token check
│   │   ├── PowerSettingExecutor.swift # Executes /usr/bin/pmset with args array
│   │   ├── main.swift           # Helper entry point (runs NSXPCListener)
│   │   └── com.preventsleep.helper.plist # Launchd property list
│   │
│   └── PreventSleepApp/         # USER MENU-BAR APPLICATION
│       ├── AppDelegate.swift    # App lifecycle & menu construction
│       ├── StatusItemController.swift # NSStatusItem, menu clicks & feedback
│       ├── BatteryMonitor.swift # IOKit power source notifications
│       ├── AppRelocator.swift   # Smart auto-move from DMG to /Applications
│       ├── SetupView.swift      # SwiftUI onboarding & approval watcher
│       └── HelperClient.swift   # XPC client connection manager
│
├── Tests/
│   └── PreventSleepCoreTests/   # FAST UNIT TEST SUITE (24 tests, ~0.17s)
├── scripts/
│   ├── release.sh               # One-command release & notarization pipeline
│   ├── package-dmg.sh           # Builds, signs with Hardened Runtime & packages DMG
│   ├── build-and-install.sh     # Local build & install to /Applications
│   ├── run-debug.sh             # Launches app in foreground with live console logs
│   ├── clean-uninstall.sh       # Nuclear reset of app, daemon, and pmset
│   └── generate-icon.swift      # Generates full 10-resolution macOS squircle icon
└── project.yml                  # XcodeGen declarative project specification
```

---

## 3. How to Execute Future Iterations

### A. Developing a New Feature
1. **Always write unit tests first:** Add test cases in `Tests/PreventSleepCoreTests/`.
2. **Run tests instantly via CLI:**
   ```bash
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
   ```
3. **If changing `project.yml`:** Regenerate the Xcode project:
   ```bash
   xcodegen generate
   ```
4. **Test live on your Mac:**
   ```bash
   ./scripts/build-and-install.sh --install
   ```
   Or run in foreground debug mode:
   ```bash
   ./scripts/run-debug.sh
   ```

### B. Publishing an Update (v1.1.0, v2.0.0, etc.)
The entire release, code signing, DMG packaging, Apple notarization, and ticket stapling is executed with **one command**:

1. Update version numbers in `project.yml`:
   ```yaml
   settings:
     MARKETING_VERSION: "1.1.0"
     CURRENT_PROJECT_VERSION: "110"
   ```
2. Update `PreventSleepBuildInfo` in `Sources/PreventSleepCore/BuildInfo.swift`:
   ```swift
   public static let version = "1.1.0"
   public static let buildNumber = "110"
   ```
3. Update `CHANGELOG.md` with release highlights.
4. Run the release pipeline:
   ```bash
   ./scripts/release.sh 1.1.0 110 preventsleep-notary
   ```
5. Verify Gatekeeper acceptance:
   ```bash
   spctl -a -vvv -t install build/PreventSleep-1.1.0.dmg
   # Output must state: accepted, source=Notarized Developer ID
   ```
6. Commit and tag the release:
   ```bash
   git add .
   git commit -m "feat: release v1.1.0"
   git tag -a v1.1.0 -m "Release v1.1.0"
   git push origin main --tags
   ```

---

## 4. Future Roadmap Opportunities

These features are planned and pre-architected for subsequent iterations:

### Milestone 1: Sparkle 2 Auto-Updates (Task T19 in Launch Plan)
* **Goal:** Allow customers to receive background updates seamlessly.
* **Prerequisite:** Web host or GitHub Releases URL for hosting `appcast.xml` and update DMGs.
* **Integration Steps:**
  1. Add Sparkle 2 Swift package dependency to `project.yml`.
  2. Generate ED25519 update key using `bin/generate_keys`.
  3. Add `SUPublicEDKey` and `SUFeedURL` to `Sources/PreventSleepApp/Resources/Info.plist`.
  4. Wire "Check for Updates..." menu item to `SUUpdaterController.shared.checkForUpdates(self)`.

### Milestone 2: Timed Sleep Prevention ("Prevent sleep for...")
* **Goal:** Allow users to set a temporary timer (e.g., 30 mins, 1 hour, 2 hours, or indefinite).
* **Architecture:**
  - Create `SleepTimerCoordinator` in `PreventSleepCore`.
  - When timer fires, dispatch `setPreventSleep(false)` through `StateCoordinator`.
  - Display remaining countdown time in the menu item or tooltip.

### Milestone 3: Commercial License Key Activation
* **Goal:** Enable software licensing via Lemon Squeezy, Gumroad, or AppSumo.
* **Architecture:**
  - Add `LicenseManager.swift` in `PreventSleepApp`.
  - Validate customer license key via Lemon Squeezy API on first activation.
  - Store cryptographically signed activation token in macOS Keychain.
  - Offline grace period: Allow full offline functionality for 30 days before requiring background re-validation.

---

## 5. Emergency Recovery & Diagnostic Runbook

If you ever encounter an issue or state mismatch while testing:

* **Inspect live unified logs:**
  ```bash
  log stream --predicate 'subsystem == "com.preventsleep.app"' --debug
  ```
* **Verify kernel power state:**
  ```bash
  pmset -g | grep -i "SleepDisabled"
  ```
* **Perform a complete clean reset (restores Mac to virgin state):**
  ```bash
  ./scripts/clean-uninstall.sh
  ```
