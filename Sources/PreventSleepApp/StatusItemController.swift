import AppKit
import PreventSleepCore

@MainActor
public final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let coordinator: StateCoordinator
    private let onOpenSetup: @MainActor () -> Void
    private let onGuidedRemoval: @MainActor () -> Void

    private var currentOperationalState: OperationalState = .reading

    public init(
        coordinator: StateCoordinator,
        onOpenSetup: @escaping @MainActor () -> Void,
        onGuidedRemoval: @escaping @MainActor () -> Void
    ) {
        self.coordinator = coordinator
        self.onOpenSetup = onOpenSetup
        self.onGuidedRemoval = onGuidedRemoval
        UserDefaults.standard.register(defaults: [
            "NSStatusItem Preferred Position PreventSleep": 1
        ])
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem.autosaveName = "PreventSleep"
        self.statusItem.behavior = [.removalAllowed]
        super.init()

        setupButton()
        update(state: currentOperationalState)
        buildMenu()

        Task {
            await coordinator.addListener { [weak self] state in
                Task { @MainActor in
                    self?.update(state: state)
                }
            }
        }
    }

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        AppLogger.shared.debug("StatusItem", "Status item clicked (isRightClick: \(isRightClick), state: \(currentOperationalState))")
        if isRightClick {
            statusItem.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
        } else {
            if currentOperationalState == .setupRequired {
                AppLogger.shared.info("StatusItem", "Setup is required. Opening setup window.")
                onOpenSetup()
            } else {
                AppLogger.shared.info("StatusItem", "Left click detected. Triggering coordinator.toggle().")
                Task {
                    await coordinator.toggle()
                }
            }
        }
    }

    public func update(state: OperationalState) {
        self.currentOperationalState = state
        let presentation = StatusPresentation.forState(state)
        AppLogger.shared.debug("StatusItem", "Updating UI icon for state: \(state) -> symbol: '\(presentation.symbolName)', tooltip: '\(presentation.tooltip)'")

        if let button = statusItem.button {
            button.image = presentation.image
            button.toolTip = presentation.tooltip
            button.setAccessibilityLabel(presentation.accessibilityLabel)
        }
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let stateDesc: String
        switch currentOperationalState {
        case .ready(let on):
            stateDesc = on ? "Prevent Sleep: ON" : "Prevent Sleep: OFF"
        case .changing:
            stateDesc = "Prevent Sleep: Changing..."
        case .unavailable(let reason):
            stateDesc = "Unavailable: \(reason)"
        case .setupRequired:
            stateDesc = "Setup Required"
        case .reading:
            stateDesc = "Reading status..."
        case .removing:
            stateDesc = "Removing..."
        }

        let headerItem = NSMenuItem(title: stateDesc, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(title: "Toggle Sleep Prevention", action: #selector(menuToggle), keyEquivalent: "t")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let setupItem = NSMenuItem(title: "Setup & Status...", action: #selector(menuOpenSetup), keyEquivalent: "s")
        setupItem.target = self
        menu.addItem(setupItem)

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(menuToggleLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = AppServiceManager.shared.isLoginItemEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())

        let removeItem = NSMenuItem(title: "Allow Sleep & Remove Helper...", action: #selector(menuRemove), keyEquivalent: "")
        removeItem.target = self
        menu.addItem(removeItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Prevent Sleep", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func menuToggle() {
        Task { await coordinator.toggle() }
    }

    @objc private func menuOpenSetup() {
        onOpenSetup()
    }

    @objc private func menuToggleLogin() {
        let current = AppServiceManager.shared.isLoginItemEnabled
        try? AppServiceManager.shared.setLoginLaunch(enabled: !current)
        buildMenu()
    }

    @objc private func menuRemove() {
        onGuidedRemoval()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }
}
