# Prevent Sleep: implementation options

Research date: 2026-09-13. Scope: a single macOS switch, initial helper approval, subsequent passwordless operation, and authoritative state. Repository initially empty; no deployment target exists. Local host: macOS 26.5.2. No power settings were changed.

## Decision

**Recommendation:** Use a native menu-bar app and an SMAppService LaunchDaemon if the switch must change a persistent machine setting. If the actual requirement is simply preventing automatic idle sleep while the app is running, use an IOKit assertion without a privileged helper. These are different product contracts, not interchangeable implementations.

## Verified options

| Option | Mechanism | Fit |
| --- | --- | --- |
| Temporary keep-awake | IOKit power assertion | No special privileges; controls an assertion rather than a persistent preference. |
| Persistent idle-sleep setting | Approved daemon invokes `pmset` with a sleep timer of zero | Documented setting; must preserve and restore prior timers for relevant power sources. |
| Persistent broad sleep-disable flag | Approved daemon invokes `pmset disablesleep 1` or `0` | Closest to a single global Boolean, but absent from the installed manual. Treat compatibility as an explicit risk. |

The assertion API requires no special privileges. `PreventUserIdleSystemSleep` permits display sleep and does not prevent lid-close, Apple-menu, or low-battery sleep. Apple exposes APIs for reading individual assertions, assertions by process, and aggregate assertion levels. Only the creating process may change an assertion's properties. [Apple IOPMLib.h: semantics](https://github.com/apple-oss-distributions/IOKitUser/blob/main/pwr_mgt.subproj/IOPMLib.h#L252-L270), [readback and ownership](https://github.com/apple-oss-distributions/IOKitUser/blob/main/pwr_mgt.subproj/IOPMLib.h#L624-L683), [privileges](https://github.com/apple-oss-distributions/IOKitUser/blob/main/pwr_mgt.subproj/IOPMLib.h#L708-L732).

`pmset` requires root to change preferences. `sleep 0` disables the idle timer; settings can differ between battery, charger, and UPS. `-g` reads current settings, while `-g custom` reads power-source profiles. Settings persist, and assertions can override their practical effect. [Installed Apple manual](evidence/pmset-macos-26.5.2.txt).

`disablesleep` is implemented in Apple's [pmset source](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmset/pmset.m#L5419-L5440), but is not described in the installed manual. The local read-only check returned `SleepDisabled 1`. This confirms the flag is currently reported here; it does not establish lid-close behavior across hardware or OS releases. [Local observation](evidence/local-observation.txt).

`pmset -g` renders the system flag from `IOPMCopySystemPowerSettings`. Direct power-preference functions used by pmset rely on private headers; do not describe them as a supported public API alternative. [Readback implementation](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmset/pmset.m#L1103-L1129), [private imports](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmset/pmset.m#L31).

## Helper approval and implementation

SMAppService supports LaunchDaemons starting with macOS 13. An administrator must approve a daemon in System Settings before it bootstraps; afterward it bootstraps on subsequent boots. Apps must be signed, and apps containing LaunchDaemons must be notarized. Revoking consent changes service status to `requiresApproval`. [Apple SDK SMAppService.h](/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/ServiceManagement.framework/Headers/SMAppService.h:49), [daemon availability](/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/ServiceManagement.framework/Headers/SMAppService.h:131), [approval](/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/ServiceManagement.framework/Headers/SMAppService.h:160), [revocation](/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/ServiceManagement.framework/Headers/SMAppService.h:22). See also [Apple's explanation](https://developer.apple.com/videos/play/wwdc2022/10096/).

**Proposed architecture:** native Swift menu-bar UI → authenticated XPC connection → narrowly scoped root daemon → fixed `pmset` arguments → readback → confirmed UI state. With the privilege boundary in the approved daemon, ordinary commands need not invoke interactive authorization. This is an architectural conclusion, not an Apple guarantee of zero latency or permanent consent.

Apple documents XPC signing requirements for validating incoming clients. [Apple DTS](https://developer.apple.com/forums/thread/681053).

Expose only `getState` and `setPreventSleep(Bool)` equivalents. Validate the connecting app's signing identity. Never expose arbitrary shell commands, paths, or arguments. Prefer direct execution of the fixed executable to a shell. Use a signed, notarized direct-distribution build as the initial engineering target; App Store acceptance has not been established by this research.

## Truthful switch contract — recommendations

- Define ON as the confirmed value of the chosen setting, not a cached user preference.
- Read on launch, menu opening, wake, and after writes; reconcile external changes while the UI is visible. Treat observations as snapshots, not an impossible guarantee against concurrent changes.
- Send an explicit desired value, serialize writes, check command status, and read back before confirming success.
- Allow a short pending state and an unavailable/error state. Never interpret failed or missing readback as OFF.
- OFF means this prevention setting is disabled. Other applications can still keep the machine awake. An aggregate assertion level cannot serve as a globally controllable toggle because the app does not own other processes' assertions.
- For the timer option, preserve each profile's previous value and handle external edits without blindly overwriting them.

The honest experience promise is: **approve during setup; no repeated authentication during normal use; show confirmed state promptly.** “Never asked again,” “zero delay,” and “OFF guarantees sleep” are too strong.

## Validation and next gate

Checked local OS, installed Apple manual, SDK signatures, and current read-only `pmset` output. The [minimal read-only API sample](evidence/assertion-api-check.c) passed `xcrun clang -fsyntax-only`; it was not executed. Helper installation, command writes, timing, restart recovery, external edits, AC/battery transitions, and lid behavior remain untested. Before committing to `disablesleep`, prototype on the intended supported Macs and OS versions. No production app was created.
