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
        guard validateClient(connection: connection) else {
            return false
        }

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
            return false
        }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
              let validStaticCode = staticCode else {
            return false
        }

        var requirement: SecRequirement?
        let reqString = "identifier \"\(Self.expectedSigningIdentifier)\"" as CFString
        guard SecRequirementCreateWithString(reqString, [], &requirement) == errSecSuccess,
              let validReq = requirement else {
            return false
        }

        let validity = SecStaticCodeCheckValidity(validStaticCode, SecCSFlags(rawValue: UInt32(kSecCSDoNotValidateResources)), validReq)
        return validity == errSecSuccess
    }

    public func getState(withReply reply: @escaping (NSNumber?, NSString?) -> Void) {
        do {
            let active = try executor.readState()
            reply(NSNumber(value: active), nil)
        } catch {
            reply(nil, error.localizedDescription as NSString)
        }
    }

    public func setPreventSleep(_ enabled: Bool, withReply reply: @escaping (NSNumber?, NSString?) -> Void) {
        do {
            let confirmed = try executor.setPreventSleep(enabled)
            reply(NSNumber(value: confirmed), nil)
        } catch {
            reply(nil, error.localizedDescription as NSString)
        }
    }
}
