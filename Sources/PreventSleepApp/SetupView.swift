import SwiftUI
import AppKit
import PreventSleepCore

public struct SetupView: View {
    @ObservedObject var viewModel: SetupViewModel

    public init(viewModel: SetupViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: "cup.and.saucer.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Welcome to Prevent Sleep")
                        .font(.title3.bold())
                    Text("One-time permission required to toggle sleep instantly")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            if viewModel.isApproved {
                // Success State
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.green)

                    Text("All Set & Ready!")
                        .font(.headline)

                    Text("The background service is active. Prevent Sleep is now in your menu bar (☕️). Click the icon anytime to toggle sleep.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)

                    // Thermal / Closed-Lid Safety Notice
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Closed-Lid Notice")
                                .font(.subheadline.bold())
                            Text("When Prevent Sleep is ON, your Mac remains active even with the display or lid closed. Do not store your laptop inside a closed bag or sleeve while active to avoid overheating.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Divider()
                        .padding(.vertical, 4)

                    Toggle("Start Prevent Sleep automatically at login", isOn: $viewModel.launchAtLogin)
                        .toggleStyle(.checkbox)
                        .font(.subheadline)

                    HStack {
                        Spacer()
                        Button("Done") {
                            viewModel.close()
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .controlSize(.large)
                    }
                    .padding(.top, 4)
                }
                .transition(.opacity.combined(with: .scale))
            } else {
                // Guidance State
                VStack(alignment: .leading, spacing: 14) {
                    Text("Follow these 2 quick steps:")
                        .font(.subheadline.bold())

                    VStack(alignment: .leading, spacing: 10) {
                        stepRow(
                            number: "1",
                            title: "Open Login Items Settings",
                            subtitle: "Click the button below to open macOS System Settings directly."
                        )

                        stepRow(
                            number: "2",
                            title: "Allow 'PreventSleep' in Background",
                            subtitle: "Under 'Allow in Background', find PreventSleep and toggle it ON."
                        )
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    // Action buttons & Live status
                    VStack(spacing: 12) {
                        Button(action: { viewModel.openSystemSettings() }) {
                            HStack {
                                Image(systemName: "gearshape")
                                Text("Open Login Items Settings")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Waiting for approval in System Settings (auto-detects)...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(24)
        .frame(width: 480)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isApproved)
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    private func stepRow(number: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 22, height: 22)
                Text(number)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@MainActor
public final class SetupViewModel: ObservableObject {
    @Published public var isApproved: Bool = false
    @Published public var statusText: String = "Checking..."
    @Published public var launchAtLogin: Bool = false {
        didSet {
            try? AppServiceManager.shared.setLoginLaunch(enabled: launchAtLogin)
        }
    }

    public var onClose: (() -> Void)?

    private let coordinator: StateCoordinator
    private var monitorTask: Task<Void, Never>?
    private var activityTask: Task<Void, Never>?
    private var hasAttemptedInitialRegister = false

    public init(coordinator: StateCoordinator) {
        self.coordinator = coordinator

        // Default launch at login to true on initial setup
        let hasConfigured = UserDefaults.standard.bool(forKey: "hasConfiguredLaunchAtLogin")
        if !hasConfigured {
            UserDefaults.standard.set(true, forKey: "hasConfiguredLaunchAtLogin")
            try? AppServiceManager.shared.setLoginLaunch(enabled: true)
            self.launchAtLogin = true
        } else {
            self.launchAtLogin = AppServiceManager.shared.isLoginItemEnabled
        }
    }

    deinit {
        monitorTask?.cancel()
        activityTask?.cancel()
    }

    public func startMonitoring() {
        checkStatus()

        // 1. Poll every 0.5s for instantaneous detection when user clicks the toggle in System Settings
        monitorTask?.cancel()
        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, !Task.isCancelled else { break }
                self.checkStatus()
            }
        }

        // 2. Immediate check when switching back from System Settings window
        activityTask?.cancel()
        activityTask = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification) {
                guard let self, !Task.isCancelled else { break }
                self.checkStatus()
            }
        }
    }

    public func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        activityTask?.cancel()
        activityTask = nil
    }

    public func checkStatus() {
        let status = AppServiceManager.shared.daemonStatus
        switch status {
        case .enabled:
            if !self.isApproved {
                AppLogger.shared.info("SetupView", "Helper daemon detected as enabled!")
                self.isApproved = true
                self.statusText = "Helper is installed and active."
            }
        case .requiresApproval:
            self.isApproved = false
            self.statusText = "Approval required in System Settings."
        case .notRegistered, .notFound:
            self.isApproved = false
            if !hasAttemptedInitialRegister {
                hasAttemptedInitialRegister = true
                do {
                    try AppServiceManager.shared.registerDaemon()
                    if AppServiceManager.shared.daemonStatus == .enabled {
                        self.isApproved = true
                        self.statusText = "Helper is installed and active."
                    }
                } catch {
                    self.statusText = "Registration: \(error.localizedDescription)"
                }
            }
        @unknown default:
            self.isApproved = false
            self.statusText = "Unknown status (\(status.rawValue))."
        }

        Task {
            await coordinator.refresh()
        }
    }

    public func openSystemSettings() {
        AppLogger.shared.info("SetupView", "Opening System Settings -> Login Items & Extensions...")
        AppServiceManager.shared.openLoginItemsSettings()
    }

    public func close() {
        stopMonitoring()
        onClose?()
    }
}
