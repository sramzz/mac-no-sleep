# Prevent Sleep — implementation plan

Status: user-approved product contract; implementation not started.
Date: 2026-09-13.

## Outcome and scope

Replace repeated authenticated Terminal commands with a reliable menu-bar switch controlling the Mac's existing `SleepDisabled` setting. Optimize for easy daily use, fast feedback, and trustworthy state.

Target macOS Tahoe 26 and later, initially validated on the owner's Mac. No older-macOS compatibility layer. Personal use first; signed, notarized direct distribution and direct sales later. A Mac App Store edition is a separate future decision: the chosen privileged architecture conflicts with current Store requirements. See [research](research/prevent-sleep-options.md) and [Apple review guideline 2.4.5](https://developer.apple.com/app-store/review/guidelines/#hardware-compatibility).

No production code is included in this plan. No timers, battery rules, schedules, analytics, accounts, licensing, automatic updater, or future-feature UI in version one. Document extension points; do not add unused stubs.

## Approved behavior

| Situation | Required behavior |
| --- | --- |
| Normal left-click | Refresh current system state, then request its opposite. |
| Normal right-click | Open options. |
| Write pending | Show a distinct busy icon; ignore further toggle clicks until resolved. |
| Successful change | Show the confirmed readback value, silently. |
| Read or connection failure | Show unavailable, never a stale ON/OFF presentation. |
| Click while unavailable | Explain the problem and offer Retry or Open System Settings. |
| Terminal or another tool changes the flag | Adopt the system value; never restore a cached preference. |
| First launch | Preserve current setting throughout setup. |
| Quit or restart | Preserve current setting; do not write a value during shutdown or startup. |
| Login | Launch controls automatically, unless the user disables login launch. |
| Helper removal | Offer “Allow Sleep & Remove Helper”; explain an active-setting change before proceeding. |

ON means the system reports `SleepDisabled = 1`; OFF means it reports `0`. This is a setting indicator, not proof that the machine will or will not sleep for every reason. Other processes and system conditions also affect sleep. Keep that explanation in help rather than interrupting everyday toggles.

## Architecture

Use a native Swift app, AppKit status item for explicit left/right-click handling, and a small SwiftUI or AppKit setup/recovery window. Use an Xcode project with two executable targets: the unprivileged app and its bundled privileged LaunchDaemon. Target macOS 26.0. Avoid third-party dependencies initially.

Register the daemon through `SMAppService.daemon(plistName:)`. Bundle its plist under `Contents/Library/LaunchDaemons`, with a fixed Mach service and bundle-relative helper executable. Install the app in `/Applications` for predictable availability. Register main-app login launch separately; helper approval and launch-at-login are different states.

Communication: app → authenticated XPC → narrowly scoped root helper → `/usr/bin/pmset` → readback → app state.

Suggested responsibilities:

- **Status controller:** presentation, click handling, accessibility, options, setup and recovery.
- **State coordinator:** serialize refresh/write operations, reject duplicate clicks, reconcile observations.
- **Helper client:** XPC lifecycle, bounded requests, reconnection, typed errors.
- **Service manager:** helper registration/status, approval navigation, login launch and removal.
- **Helper:** authenticate clients, accept only fixed operations, execute commands and validate readback.
- **Power-setting adapter:** strict output parsing and fixed command execution; independently testable.

Do not bind private IOKit preference APIs. Running `pmset` avoids a private API binding but does not eliminate the compatibility risk of its undocumented `disablesleep` argument. Preserve this risk in release checks.

## Privilege boundary and protocol

Use stable bundle identifiers and signing identities. Validate incoming XPC clients against the intended app's designated signing requirement, including the expected identifier and team; do not trust a caller-supplied PID or bundle identifier. Configure helper-side incoming-message signing checks using the supported API on the target OS. Verify the server identity where the chosen transport supports it; do not treat a service-name string as authentication. Review [Apple's XPC guidance](https://developer.apple.com/forums/thread/681053).

The helper's privileged surface should expose only equivalents of:

- `getState`: confirmed Boolean or a typed error, plus a protocol version and observation metadata as needed.
- `setPreventSleep(enabled)`: explicit desired Boolean; return the observed result only after the command completes and readback confirms it.

The app manages SMAppService registration/removal. Do not expose arbitrary executable paths, shell strings, arguments, file operations, or a generic privileged command endpoint. Launch the absolute `/usr/bin/pmset` executable directly with fixed argument arrays; never invoke a shell or `sudo`.

Writes use `disablesleep 1` or `disablesleep 0`. Read the system-wide `SleepDisabled` field from `pmset -g`. Require a recognized, unambiguous value. Missing, malformed, contradictory, or unknown output means unavailable; do not equate a missing field with OFF. If fresh-system behavior differs, investigate it explicitly before changing this rule.

Require command success and matching readback. A nonzero exit, timeout, malformed output, or mismatched readback is not success. Bound process duration and output collection; distinguish errors sufficiently to choose the correct recovery action without displaying raw diagnostics as primary UX.

Serialize helper writes. Make repeated requests for an already-established explicit value harmless. After an uncertain timeout, reread before permitting a new toggle; never blindly retry an ambiguous inversion. Account for delayed completions so old responses cannot overwrite newer observations.

## UI state and synchronization

Maintain explicit states: setup required, reading/unavailable, ready ON, ready OFF, changing, and removing. Helper approval status and connection health are separate from the sleep value. A service being registered does not prove it is reachable or working.

Use distinct icon shapes or badges for ON/OFF/unavailable and a visible busy treatment for pending. Provide tooltips and accessibility labels such as “Prevent Sleep: On,” “Changing sleep setting,” and “Sleep setting unavailable.” Do not depend only on color. Expose a keyboard-accessible equivalent of the toggle and options; right-click must not be the sole route to essential controls.

Normal click sequence:

1. Enter pending immediately so the click is visibly acknowledged.
2. Fetch fresh system state. If it fails, show unavailable without writing.
3. Send the explicit opposite value.
4. Wait for command completion and confirmed readback.
5. Render the observed state, or show a concise failure with Retry.

Keep polling from racing with writes. During a mutation, ignore stale refresh results; run a fresh reconciliation afterward. External processes can still race with this app, so do not promise atomic control over all writers.

Refresh in the background, even with the menu closed, with a target of reflecting external changes within two seconds while the app is awake and responsive. Start with a one-second refresh cadence, allow only one refresh in flight, and measure overhead. Coalesce wake/menu-open/click refreshes. If process spawning is too expensive, revisit the read mechanism based on public APIs and measured evidence without weakening the state contract.

Refresh immediately after wake, opening options, reconnecting, approval changes, and before toggling. Suspend routine refresh during sleep. Do not claim a two-second hard guarantee under system stalls. A failed read makes the visible state unavailable; retain last-known values only for diagnostics.

Routine successes are silent. Errors remain discoverable on the icon and in the small recovery surface; no repetitive dialogs or notifications during background failures.

## Setup and recovery

First launch shows a brief explanation: the helper changes the system sleep setting so future toggles do not require authentication. Offer setup and explain the action needed in **System Settings → General → Login Items & Extensions**. Use the system navigation API for Login Items rather than relying on an undocumented URL. Check the actual Tahoe screen labels during validation.

Register the helper, inspect its status, and offer **Open System Settings** when approval is required. Detect readiness automatically when the user returns and with bounded status checks while setup is visible. Show **Ready** only after approval, a working XPC connection, and successful readback. No setup step writes the sleep flag.

Handle rejected approval, disabled background service, moved/missing app, invalid signature, and protocol mismatch distinctly in diagnostics. User-facing recovery should stay small: explain what is unavailable and provide **Retry** or **Open System Settings** as appropriate. Never fall back to fingerprint/password authorization for an ordinary toggle.

Enable launch at login as part of setup. Reflect the actual login-service state in options and honor subsequent user changes. Do not repeatedly re-enable something the user disabled.

Approval is expected once during normal installation, not guaranteed forever: revocation and installation/signing problems require recovery. Signed/notarized installation is an early feasibility gate, not a final packaging afterthought. Verify the necessary development signing/notarization workflow on the intended machine before building the full UI.

## Quit, removal, and updates

**Quit:** stop the controls and polling without changing the setting. Do not unregister the helper merely because the UI quits. Keep a toggle operation bounded and finish or resolve it before exiting; do not silently cancel a partially applied write.

**Allow Sleep & Remove Helper:** read state, explain any active-setting change, and require the explicit removal action. Set `disablesleep 0`, confirm it, then unregister the helper and disable this app's login launch. If disabling sleep prevention cannot be confirmed, do not report successful cleanup or automatically proceed past that failure. If unregistration fails, report the partial result accurately. Removal does not itself delete the app bundle.

Document that dragging the app to Trash is not a reliable opportunity to run cleanup. Persistent sleep state can outlive the app. Provide manual recovery instructions in documentation for an unavailable helper; never execute an authenticated fallback silently.

For local rebuilds and later distribution updates, keep signing/service identifiers stable and verify helper/app protocol compatibility. Detect mismatches with actionable recovery. Automated updates, payments and licensing remain outside version one.

## Implementation sequence

### 1. Prove the privileged path

Create app/helper targets, signing configuration, bundled daemon plist and narrow XPC protocol. Verify install, administrator approval, authenticated connection, rejection of an unauthorized client, and a read-only state request on Tahoe. Test the signed installed build, not only an Xcode launch.

Exit criterion: the helper is reachable after approval and after reboot, and app startup preserves the current flag.

### 2. Implement setting operations

Add fixed command execution, strict parsing, serialization, timeouts and confirmed readback. Add explicit set operations and typed failures. Record the original flag before manual integration checks and restore it afterward.

Exit criterion: both directions work without repeated authentication; failed and uncertain operations never return false success.

### 3. Build the daily control

Add status item, left-click toggle, right-click options, keyboard access, four distinct operational presentations, pending-click suppression and state coordinator. Add polling and event-triggered refreshes.

Exit criterion: the app behaves correctly under rapid clicks and external Terminal changes without stale results overwriting newer state.

### 4. Finish lifecycle UX

Add setup, System Settings navigation, readiness detection, login launch, approval revocation recovery, reconnection, Quit and guided helper removal.

Exit criterion: setup and failures require no Terminal knowledge; routine use never invokes authentication.

### 5. Validate and document

Run the acceptance checks below against the installed release-style build. Measure read/write and refresh costs. Document installation, build/signing, removal, troubleshooting and the undocumented-command risk. Keep the original system flag after validation unless the owner intentionally chooses another value.

## Acceptance checks

| Check | Expected result |
| --- | --- |
| Fresh setup while ON, repeated while OFF | Approval flow preserves the starting flag; Ready follows successful readback. |
| Toggle both ways repeatedly | Confirmed values match `pmset -g`; no recurring password or Touch ID prompt. |
| Rapid/double clicks | One operation while pending; no queued reversal. |
| External change while menu is closed | Icon adopts it within the two-second target under normal conditions. |
| External change during pending operation | Reconciliation shows current observed state; no automatic fight with the external writer. |
| Failed read or malformed/missing flag | Unavailable; never assumed OFF. |
| Write error, timeout, or mismatched readback | No success presentation; appropriate Retry and subsequent reconciliation. |
| Helper terminated or connection interrupted | Unavailable then recovery; no stale completion applied. |
| Approval revoked | Open System Settings recovery; no authentication fallback. |
| Quit/relaunch and reboot/login | Flag preserved; login controls return when enabled. |
| Sleep/wake and AC/battery change | Refresh resumes correctly; no automatic flag changes. |
| Guided removal while ON | Explanation, confirmed OFF, then helper removal and login cleanup. |
| Removal partly fails | Accurate partial-result message; no false completion. |
| Keyboard and non-color use | State and primary actions remain understandable and operable. |
| Unauthorized XPC client | Privileged operations rejected. |
| Local rebuild/update | Compatible app/helper reconnect; mismatch produces actionable recovery. |

Automate parser and state-coordinator tests with representative valid/error output and controlled delayed responses. Test the actual privileged path manually in a signed installed build; mocks alone cannot validate approval, identity checks, launchd lifecycle or system setting changes.

## Remaining implementation investigations

These are engineering checks, not unsettled product decisions:

- Confirm Tahoe installation, signing/notarization and System Settings navigation with the developer account used for the build.
- Measure polling overhead and command latency; tune timeouts and refresh scheduling based on evidence.
- Confirm `SleepDisabled` readback on the actual target configuration; do not generalize the owner's existing `1` observation to every fresh installation.
- Verify cleanup and service refresh across local updates using current SMAppService lifecycle guidance.

The authoritative reference for API findings and known limits is [the research note](research/prevent-sleep-options.md). Future automatic rules should submit explicit values through the same coordinator/helper boundary, without changing the meaning of confirmed state.
