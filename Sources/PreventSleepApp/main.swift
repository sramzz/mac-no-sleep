import AppKit

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

if CommandLine.arguments.contains("--toggle") {
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

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
