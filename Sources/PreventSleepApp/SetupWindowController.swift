import AppKit
import SwiftUI
import PreventSleepCore

@MainActor
public final class SetupWindowController: NSWindowController {
    public convenience init(coordinator: StateCoordinator) {
        let viewModel = SetupViewModel(coordinator: coordinator)
        let hostingController = NSHostingController(rootView: SetupView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable]
        window.title = "Prevent Sleep Setup"
        window.center()

        self.init(window: window)
        viewModel.onClose = { [weak self] in
            self?.close()
        }
    }
}
