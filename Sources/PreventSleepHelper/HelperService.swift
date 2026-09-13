import Foundation
import Security
import PreventSleepCore

public final class HelperService: NSObject, PreventSleepXPCProtocol, NSXPCListenerDelegate {
    private let executor: PowerSettingExecutor
    public static let machServiceName = "com.sramzz.mac-no-sleep.helper"
    public static let expectedSigningIdentifier = "com.sramzz.mac-no-sleep"

    public init(executor: PowerSettingExecutor = PowerSettingExecutor()) {
        self.executor = executor
        super.init()
    }

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        AppLogger.shared.info("HelperService", "Incoming connection request from PID: \(connection.processIdentifier)")
        guard validateClient(connection: connection) else {
            AppLogger.shared.error("HelperService", "Rejecting connection from PID \(connection.processIdentifier): Code signature validation failed")
            return false
        }

        AppLogger.shared.info("HelperService", "Accepted connection from client PID: \(connection.processIdentifier)")
        connection.exportedInterface = NSXPCInterface(with: PreventSleepXPCProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    public func validateClient(connection: NSXPCConnection) -> Bool {
        let pid = connection.processIdentifier
        let attributes: [CFString: Any] = [
            kSecGuestAttributePid: pid
        ]

        var secCode: SecCode?
        let copyStatus = SecCodeCopyGuestWithAttributes(nil, attributes as CFDictionary, [], &secCode)
        guard copyStatus == errSecSuccess, let code = secCode else {
            AppLogger.shared.error("HelperService", "SecCodeCopyGuestWithAttributes failed for PID \(pid): \(copyStatus)")
            return false
        }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
              let validStaticCode = staticCode else {
            AppLogger.shared.error("HelperService", "SecCodeCopyStaticCode failed for PID \(pid)")
            return false
        }

        var requirement: SecRequirement?
        let reqString = "identifier \"\(Self.expectedSigningIdentifier)\"" as CFString
        guard SecRequirementCreateWithString(reqString, [], &requirement) == errSecSuccess,
              let validReq = requirement else {
            AppLogger.shared.error("HelperService", "SecRequirementCreateWithString failed for identifier '\(Self.expectedSigningIdentifier)'")
            return false
        }

        let validity = SecStaticCodeCheckValidity(validStaticCode, SecCSFlags(rawValue: UInt32(kSecCSDoNotValidateResources)), validReq)
        let isValid = validity == errSecSuccess
        if !isValid {
            AppLogger.shared.error("HelperService", "SecStaticCodeCheckValidity failed for PID \(pid): OSStatus \(validity)")
        }
        return isValid
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
}
