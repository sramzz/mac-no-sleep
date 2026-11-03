import AppKit
import PreventSleepCore

if CommandLine.arguments.contains("--version") || CommandLine.arguments.contains("-v") {
    print("Prevent Sleep App: \(PreventSleepBuildInfo.displayVersion)")
    let client = HelperClient()
    Task {
        do {
            let helperVersion = try await client.getVersion(timeoutSeconds: 3.0)
            print("Prevent Sleep Helper Daemon: \(helperVersion)")
            exit(0)
        } catch {
            print("Prevent Sleep Helper Daemon: Not reachable (\(error.localizedDescription))")
            exit(0)
        }
    }
    RunLoop.main.run()
}

if CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h") {
    print("""
    Prevent Sleep ☕️ \(PreventSleepBuildInfo.displayVersion)
    Native macOS persistent sleep prevention utility.

    Usage:
      PreventSleep [options]

    Options:
      --toggle, -t         Toggle sleep prevention setting (ON <-> OFF)
      --test-helper        Verify connectivity and authentication with helper daemon
      --register           Register privileged LaunchDaemon with launchd
      --unregister         Unregister LaunchDaemon from launchd
      --version, -v        Display app and daemon version info
      --help, -h           Show this help information
    """)
    exit(0)
}

if CommandLine.arguments.contains("--unregister") {
    do {
        try AppServiceManager.shared.unregisterDaemon()
        print("Successfully unregistered daemon.")
        exit(0)
    } catch {
        fputs("Failed to unregister daemon: \(error)\n", stderr)
        exit(1)
    }
}

if CommandLine.arguments.contains("--test-helper") {
    let client = HelperClient()
    Task {
        do {
            print("Requesting helper getState()...")
            let state = try await client.getState(timeoutSeconds: 5.0)
            print("Helper getState() succeeded! Active = \(state)")
            exit(0)
        } catch {
            fputs("Helper getState() failed: \(error)\n", stderr)
            exit(1)
        }
    }
    RunLoop.main.run()
}

if CommandLine.arguments.contains("--toggle") || CommandLine.arguments.contains("-t") {
    let client = HelperClient()
    Task {
        do {
            let current = try await client.getState(timeoutSeconds: 5.0)
            let target = !current
            print("Current state = \(current). Requesting target = \(target)...")
            let confirmed = try await client.setPreventSleep(target, timeoutSeconds: 10.0)
            print("Helper setPreventSleep(\(target)) succeeded! Confirmed = \(confirmed)")
            exit(0)
        } catch {
            fputs("Helper toggle failed: \(error)\n", stderr)
            exit(1)
        }
    }
    RunLoop.main.run()
}

if CommandLine.arguments.contains("--register") {
    do {
        try AppServiceManager.shared.registerDaemon()
        print("Successfully registered daemon. Status: \(AppServiceManager.shared.daemonStatus.rawValue)")
        exit(0)
    } catch {
        fputs("Failed to register daemon: \(error)\n", stderr)
        exit(1)
    }
}

// Single-instance enforcement for GUI launches
let runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: PreventSleepSecurity.appIdentifier)
let currentPID = ProcessInfo.processInfo.processIdentifier
if let existing = runningInstances.first(where: { $0.processIdentifier != currentPID }) {
    existing.activate(options: [.activateIgnoringOtherApps])
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
