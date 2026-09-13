import Foundation
import PreventSleepCore

public final class HelperClient: Sendable {
    private let machServiceName: String

    public init(machServiceName: String = "com.sramzz.mac-no-sleep.helper") {
        self.machServiceName = machServiceName
    }

    private func createConnection() -> NSXPCConnection {
        let conn = NSXPCConnection(machServiceName: machServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: PreventSleepXPCProtocol.self)
        conn.resume()
        return conn
    }

    public func getState() async throws -> Bool {
        let conn = createConnection()
        defer { conn.invalidate() }

        return try await withCheckedThrowingContinuation { continuation in
            guard let proxy = conn.remoteObjectProxyWithErrorHandler({ error in
                continuation.resume(throwing: PreventSleepError.helperUnreachable(error.localizedDescription))
            }) as? PreventSleepXPCProtocol else {
                continuation.resume(throwing: PreventSleepError.helperUnreachable("Could not obtain remote proxy"))
                return
            }

            proxy.getState { number, errorString in
                if let errorString = errorString {
                    continuation.resume(throwing: PreventSleepError.commandFailed(exitCode: -1, message: String(errorString)))
                } else if let number = number {
                    continuation.resume(returning: number.boolValue)
                } else {
                    continuation.resume(throwing: PreventSleepError.missingField)
                }
            }
        }
    }

    public func setPreventSleep(_ enabled: Bool) async throws -> Bool {
        let conn = createConnection()
        defer { conn.invalidate() }

        return try await withCheckedThrowingContinuation { continuation in
            guard let proxy = conn.remoteObjectProxyWithErrorHandler({ error in
                continuation.resume(throwing: PreventSleepError.helperUnreachable(error.localizedDescription))
            }) as? PreventSleepXPCProtocol else {
                continuation.resume(throwing: PreventSleepError.helperUnreachable("Could not obtain remote proxy"))
                return
            }

            proxy.setPreventSleep(enabled) { number, errorString in
                if let errorString = errorString {
                    continuation.resume(throwing: PreventSleepError.commandFailed(exitCode: -1, message: String(errorString)))
                } else if let number = number {
                    continuation.resume(returning: number.boolValue)
                } else {
                    continuation.resume(throwing: PreventSleepError.missingField)
                }
            }
        }
    }
}
