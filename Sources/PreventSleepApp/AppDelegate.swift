import AppKit
import PreventSleepCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: StateCoordinator!
    private var statusController: StatusItemController!
    private var setupWindowController: SetupWindowController?
    private var pollingTimer: Timer?
    private var batteryMonitor: BatteryMonitor?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        if AppRelocator.checkLocationAndPrompt() {
            return
        }

        AppLogger.shared.info("AppDelegate", "Application did finish launching (PID: \(ProcessInfo.processInfo.processIdentifier)). Version: \(PreventSleepBuildInfo.displayVersion). Log level: \(AppLogger.shared.level.label)")

        let client = HelperClient()

        coordinator = StateCoordinator(
            fetchHandler: { [weak self] in
                if AppServiceManager.shared.daemonStatus != .enabled {
                    AppLogger.shared.trace("AppDelegate", "Daemon status is not enabled (\(AppServiceManager.shared.daemonStatus.rawValue)), throwing helperNotInstalled")
                    throw PreventSleepError.helperNotInstalled
                }
                if let current = self?.readCurrentSleepDisabled() {
                    AppLogger.shared.trace("AppDelegate", "Direct pmset read returned: \(current)")
                    return current
                }
                AppLogger.shared.debug("AppDelegate", "Direct read returned nil, falling back to helper XPC")
                return try await client.getState()
            },
            mutateHandler: {
                if AppServiceManager.shared.daemonStatus != .enabled {
                    AppLogger.shared.error("AppDelegate", "Cannot mutate: daemon status is \(AppServiceManager.shared.daemonStatus.rawValue)")
                    throw PreventSleepError.helperNotInstalled
                }
                AppLogger.shared.info("AppDelegate", "Dispatching mutation via HelperClient: setPreventSleep(\($0))")
                return try await client.setPreventSleep($0)
            }
        )

        statusController = StatusItemController(
            coordinator: coordinator,
            onOpenSetup: { [weak self] in self?.showSetupWindow() },
            onGuidedRemoval: { [weak self] in self?.performGuidedRemoval() }
        )

        // Initialize Low-Battery Safeguard Monitor
        batteryMonitor = BatteryMonitor(threshold: BatteryGuard.defaultThresholdPercent) { [weak self] in
            Task { @MainActor [weak self] in
                AppLogger.shared.warning("AppDelegate", "Auto-disarming sleep prevention due to low battery threshold.")
                _ = try? await self?.coordinator.forceSet(false)
            }
        }

        // Keep battery monitor in sync with sleep prevention state
        Task {
            await coordinator.addListener { [weak self] state in
                Task { @MainActor in
                    if case .ready(let isPreventing) = state {
                        self?.batteryMonitor?.updateSleepState(isPreventing: isPreventing)
                    } else {
                        self?.batteryMonitor?.updateSleepState(isPreventing: false)
                    }
                }
            }
        }

        // Register daemon with launchd
        AppLogger.shared.info("AppDelegate", "Registering LaunchDaemon via SMAppService...")
        do {
            try AppServiceManager.shared.registerDaemon()
            AppLogger.shared.info("AppDelegate", "SMAppService register daemon succeeded. Status: \(AppServiceManager.shared.daemonStatus.rawValue)")
        } catch {
            AppLogger.shared.warning("AppDelegate", "SMAppService register daemon notice: \(error.localizedDescription) (Status: \(AppServiceManager.shared.daemonStatus.rawValue))")
        }

        // Version Handshake & Auto-Upgrade
        if AppServiceManager.shared.daemonStatus == .enabled {
            Task {
                do {
                    let helperVersion = try await client.getVersion(timeoutSeconds: 3.0)
                    AppLogger.shared.info("AppDelegate", "Helper daemon version confirmed: \(helperVersion) (App: \(PreventSleepBuildInfo.version))")
                    if helperVersion != PreventSleepBuildInfo.version {
                        AppLogger.shared.warning("AppDelegate", "Daemon version mismatch (\(helperVersion) != \(PreventSleepBuildInfo.version)). Upgrading registration...")
                        try? AppServiceManager.shared.unregisterDaemon()
                        try? AppServiceManager.shared.registerDaemon()
                    }
                } catch {
                    AppLogger.shared.debug("AppDelegate", "Helper version check notice: \(error.localizedDescription)")
                }
            }
        }

        // Show setup if approval required or not yet enabled
        if AppServiceManager.shared.daemonStatus != .enabled {
            AppLogger.shared.info("AppDelegate", "Daemon not enabled (status \(AppServiceManager.shared.daemonStatus.rawValue)). Showing Setup window.")
            showSetupWindow()
        }

        // Initial refresh
        Task {
            AppLogger.shared.debug("AppDelegate", "Triggering initial state refresh...")
            await coordinator.refresh()
            if AppServiceManager.shared.daemonStatus != .enabled {
                await MainActor.run { [weak self] in
                    self?.showSetupWindow()
                }
            }
        }

        // Background polling with timer coalescing (20s interval, 5s tolerance to reduce energy consumption)
        let timer = Timer(timeInterval: 20.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.coordinator.refresh()
            }
        }
        timer.tolerance = 5.0
        RunLoop.main.add(timer, forMode: .common)
        self.pollingTimer = timer

        // Wake notification
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            AppLogger.shared.info("AppDelegate", "System did wake from sleep notification received. Refreshing state.")
            Task { [weak self] in
                await self?.coordinator.refresh()
            }
        }
    }

    public func showSetupWindow() {
        if setupWindowController == nil {
            setupWindowController = SetupWindowController(coordinator: coordinator)
        }
        setupWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func performGuidedRemoval() {
        let alert = NSAlert()
        alert.messageText = "Allow Sleep & Remove Helper"
        alert.informativeText = "This will set the Mac sleep setting back to normal (Allow Sleep), unregister the privileged background helper, and remove launch at login."
        alert.addButton(withTitle: "Remove Helper")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            Task {
                var settingChanged = false
                do {
                    // 1. Force setting to OFF and confirm readback
                    _ = try await coordinator.forceSet(false)
                    settingChanged = true
                } catch {
                    // Check if current system setting is already OFF
                    let currentPmset = self.readCurrentSleepDisabled()
                    if currentPmset == false {
                        settingChanged = true
                    } else {
                        let failureAlert = NSAlert()
                        failureAlert.messageText = "Could Not Change Sleep Setting"
                        failureAlert.informativeText = "Could not confirm sleep setting change via helper: \(error.localizedDescription)\n\nWould you like to unregister the helper anyway? You can run 'sudo pmset disablesleep 0' in Terminal to allow sleep manually."
                        failureAlert.addButton(withTitle: "Unregister Helper Anyway")
                        failureAlert.addButton(withTitle: "Cancel")
                        failureAlert.alertStyle = .critical
                        if failureAlert.runModal() != .alertFirstButtonReturn {
                            return
                        }
                    }
                }

                do {
                    // 2. Unregister LaunchDaemon
                    try AppServiceManager.shared.unregisterDaemon()

                    // 3. Disable Login Item
                    try? AppServiceManager.shared.setLoginLaunch(enabled: false)

                    let infoAlert = NSAlert()
                    infoAlert.messageText = "Helper Removed"
                    if settingChanged {
                        infoAlert.informativeText = "The helper has been unregistered and sleep is now allowed. You can now safely quit and move Prevent Sleep to Trash."
                    } else {
                        infoAlert.informativeText = "The helper has been unregistered. Remember to run 'sudo pmset disablesleep 0' in Terminal to restore normal sleep."
                    }
                    infoAlert.runModal()
                } catch {
                    let errAlert = NSAlert()
                    errAlert.messageText = "Unregister Failed"
                    errAlert.informativeText = "Failed to unregister helper daemon: \(error.localizedDescription)"
                    errAlert.alertStyle = .critical
                    errAlert.runModal()
                }
            }
        }
    }

    private nonisolated func readCurrentSleepDisabled() -> Bool? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let out = String(data: data, encoding: .utf8) {
                return try? PowerSettingParser.parseSleepDisabled(from: out)
            }
        } catch {
            return nil
        }
        return nil
    }
}
