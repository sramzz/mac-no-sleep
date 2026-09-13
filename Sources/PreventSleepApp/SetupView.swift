import SwiftUI
import PreventSleepCore

public struct SetupView: View {
    @ObservedObject var viewModel: SetupViewModel

    public init(viewModel: SetupViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "cup.and.saucer.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prevent Sleep")
                        .font(.headline)
                    Text("System power setting controller")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Privileged Helper Status:")
                    .font(.subheadline.bold())

                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(viewModel.statusText)
                        .font(.body)
                }

                Text("To toggle sleep prevention without repeated password prompts, the background helper must be approved in System Settings → General → Login Items & Extensions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button("Open System Settings") {
                    viewModel.openSystemSettings()
                }

                Button("Retry & Check Approval") {
                    viewModel.checkStatus()
                }

                Spacer()

                if viewModel.isApproved {
                    Text("Ready")
                        .foregroundStyle(.green)
                        .bold()
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    viewModel.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear {
            viewModel.checkStatus()
        }
    }

    private var statusColor: Color {
        if viewModel.isApproved { return .green }
        return .orange
    }
}

@MainActor
public final class SetupViewModel: ObservableObject {
    @Published public var isApproved: Bool = false
    @Published public var statusText: String = "Checking..."
    public var onClose: (() -> Void)?

    private let coordinator: StateCoordinator

    public init(coordinator: StateCoordinator) {
        self.coordinator = coordinator
    }

    public func checkStatus() {
        let status = AppServiceManager.shared.daemonStatus
        switch status {
        case .enabled:
            self.isApproved = true
            self.statusText = "Helper is installed and active."
        case .requiresApproval:
            self.isApproved = false
            self.statusText = "Approval required in System Settings."
        case .notRegistered:
            self.isApproved = false
            self.statusText = "Helper is not registered."
            try? AppServiceManager.shared.registerDaemon()
        case .notFound:
            self.isApproved = false
            self.statusText = "Helper executable or plist not found."
        @unknown default:
            self.isApproved = false
            self.statusText = "Unknown status (\(status.rawValue))."
        }

        Task {
            await coordinator.refresh()
        }
    }

    public func openSystemSettings() {
        AppServiceManager.shared.openLoginItemsSettings()
    }

    public func close() {
        onClose?()
    }
}
