import Foundation
import Security
import PreventSleepCore

public final class HelperService: NSObject, PreventSleepXPCProtocol, NSXPCListenerDelegate, @unchecked Sendable {
    private let executor: PowerSettingExecutor
    private let idleTimeoutSeconds: TimeInterval?
    private let idleQueue = DispatchQueue(label: "com.preventsleep.helper.idle")
    private var idleWorkItem: DispatchWorkItem?
    public static let machServiceName = PreventSleepSecurity.helperIdentifier

    public init(executor: PowerSettingExecutor = PowerSettingExecutor(), idleTimeoutSeconds: TimeInterval? = nil) {
        self.executor = executor
        self.idleTimeoutSeconds = idleTimeoutSeconds
        super.init()
        resetIdleTimer()
    }

    private func resetIdleTimer() {
        guard let timeout = idleTimeoutSeconds else { return }
        idleQueue.async { [weak self] in
            guard let self else { return }
            self.idleWorkItem?.cancel()
            let workItem = DispatchWorkItem {
                AppLogger.shared.info("HelperService", "Helper idle for \(Int(timeout))s; exiting cleanly until next on-demand launchd request.")
                exit(0)
            }
            self.idleWorkItem = workItem
            self.idleQueue.asyncAfter(deadline: .now() + timeout, execute: workItem)
        }
    }

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        resetIdleTimer()
        AppLogger.shared.info("HelperService", "Incoming connection request from PID: \(connection.processIdentifier)")

        // Enforce code signing requirement using macOS kernel audit-token verification
        // Requires Apple cryptographic anchor, app bundle ID, and matching developer Team ID
        connection.setCodeSigningRequirement(PreventSleepSecurity.clientRequirement)

        connection.exportedInterface = NSXPCInterface(with: PreventSleepXPCProtocol.self)
        connection.exportedObject = self
        connection.resume()

        AppLogger.shared.info("HelperService", "Accepted connection from client PID: \(connection.processIdentifier)")
        return true
    }

    public func getState(withReply reply: @escaping (NSNumber?, NSString?) -> Void) {
        resetIdleTimer()
        AppLogger.shared.debug("HelperService", "Handling getState XPC request")
        do {
            let active = try executor.readState()
            AppLogger.shared.debug("HelperService", "getState returning active = \(active)")
            reply(NSNumber(value: active), nil)
        } catch {
            AppLogger.shared.error("HelperService", "getState error: \(error.localizedDescription)")
            reply(nil, error.localizedDescription as NSString)
        }
        resetIdleTimer()
    }

    public func setPreventSleep(_ enabled: Bool, withReply reply: @escaping (NSNumber?, NSString?) -> Void) {
        resetIdleTimer()
        AppLogger.shared.info("HelperService", "⚡ Handling setPreventSleep(\(enabled)) XPC request")
        do {
            let confirmed = try executor.setPreventSleep(enabled)
            AppLogger.shared.info("HelperService", "✅ setPreventSleep(\(enabled)) succeeded, confirmed = \(confirmed)")
            reply(NSNumber(value: confirmed), nil)
        } catch {
            AppLogger.shared.error("HelperService", "❌ setPreventSleep(\(enabled)) failed: \(error.localizedDescription)")
            reply(nil, error.localizedDescription as NSString)
        }
        resetIdleTimer()
    }

    public func getVersion(withReply reply: @escaping (NSString) -> Void) {
        resetIdleTimer()
        AppLogger.shared.debug("HelperService", "Handling getVersion XPC request -> \(PreventSleepBuildInfo.version)")
        reply(PreventSleepBuildInfo.version as NSString)
        resetIdleTimer()
    }
}
