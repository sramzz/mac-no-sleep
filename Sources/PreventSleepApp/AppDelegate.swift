import AppKit
import PreventSleepCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: StateCoordinator!
    private var statusController: StatusItemController!
    private var setupWindowController: SetupWindowController?
    private var pollingTimer: Timer?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let client = HelperClient()

        coordinator = StateCoordinator(
            fetchHandler: { try await client.getState() },
            mutateHandler: { try await client.setPreventSleep($0) }
        )

        statusController = StatusItemController(
            coordinator: coordinator,
            onOpenSetup: { [weak self] in self?.showSetupWindow() },
            onGuidedRemoval: { [weak self] in self?.performGuidedRemoval() }
        )

        // Register daemon if not yet registered
        if AppServiceManager.shared.daemonStatus == .notRegistered {
            try? AppServiceManager.shared.registerDaemon()
        }

        // Show setup if approval required
        if AppServiceManager.shared.daemonStatus == .requiresApproval {
            showSetupWindow()
        }

        // Initial refresh
        Task {
            await coordinator.refresh()
        }

        // Background polling every 1 second
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.coordinator.refresh()
            }
        }

        // Wake notification
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
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
                do {
                    // 1. Force setting to OFF and confirm readback
                    _ = try await coordinator.forceSet(false)

                    // 2. Unregister LaunchDaemon
                    try AppServiceManager.shared.unregisterDaemon()

                    // 3. Disable Login Item
                    try? AppServiceManager.shared.setLoginLaunch(enabled: false)

                    let infoAlert = NSAlert()
                    infoAlert.messageText = "Helper Removed"
                    infoAlert.informativeText = "The helper has been unregistered and sleep is now allowed. You can now safely quit and move Prevent Sleep to Trash."
                    infoAlert.runModal()
                } catch {
                    let errAlert = NSAlert()
                    errAlert.messageText = "Removal Incomplete"
                    errAlert.informativeText = "Could not confirm sleep setting change: \(error.localizedDescription)\n\nThe helper was not unregistered."
                    errAlert.alertStyle = .critical
                    errAlert.runModal()
                }
            }
        }
    }
}
