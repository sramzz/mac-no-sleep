import Foundation
import Security
import PreventSleepCore

public final class HelperService: NSObject, PreventSleepXPCProtocol, NSXPCListenerDelegate {
    private let executor: PowerSettingExecutor
    public static let machServiceName = PreventSleepSecurity.helperIdentifier

    public init(executor: PowerSettingExecutor = PowerSettingExecutor()) {
        self.executor = executor
        super.init()
    }

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
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
        AppLogger.shared.debug("HelperService", "Handling getState XPC request")
        do {
            let active = try executor.readState()
            AppLogger.shared.debug("HelperService", "getState returning active = \(active)")
            reply(NSNumber(value: active), nil)
        } catch {
            AppLogger.shared.error("HelperService", "getState error: \(error.localizedDescription)")
            reply(nil, error.localizedDescription as NSString)
        }
    }

    public func setPreventSleep(_ enabled: Bool, withReply reply: @escaping (NSNumber?, NSString?) -> Void) {
        AppLogger.shared.info("HelperService", "⚡ Handling setPreventSleep(\(enabled)) XPC request")
        do {
            let confirmed = try executor.setPreventSleep(enabled)
            AppLogger.shared.info("HelperService", "✅ setPreventSleep(\(enabled)) succeeded, confirmed = \(confirmed)")
            reply(NSNumber(value: confirmed), nil)
        } catch {
            AppLogger.shared.error("HelperService", "❌ setPreventSleep(\(enabled)) failed: \(error.localizedDescription)")
            reply(nil, error.localizedDescription as NSString)
        }
    }

    public func getVersion(withReply reply: @escaping (NSString) -> Void) {
        AppLogger.shared.debug("HelperService", "Handling getVersion XPC request -> \(PreventSleepBuildInfo.version)")
        reply(PreventSleepBuildInfo.version as NSString)
    }
}
