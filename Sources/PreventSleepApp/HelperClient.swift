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

    public func getState(timeoutSeconds: Double = 5.0) async throws -> Bool {
        try await withTimeout(seconds: timeoutSeconds) { [self] in
            let conn = createConnection()
            defer { conn.invalidate() }

            return try await withCheckedThrowingContinuation { continuation in
                let lock = NSLock()
                var hasResumed = false

                func resumeOnce(with result: Result<Bool, Error>) {
                    lock.lock()
                    defer { lock.unlock() }
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(with: result)
                    }
                }

                guard let proxy = conn.remoteObjectProxyWithErrorHandler({ error in
                    resumeOnce(with: .failure(PreventSleepError.helperUnreachable(error.localizedDescription)))
                }) as? PreventSleepXPCProtocol else {
                    resumeOnce(with: .failure(PreventSleepError.helperUnreachable("Could not obtain remote proxy")))
                    return
                }

                proxy.getState { number, errorString in
                    if let errorString = errorString {
                        resumeOnce(with: .failure(PreventSleepError.commandFailed(exitCode: -1, message: String(errorString))))
                    } else if let number = number {
                        resumeOnce(with: .success(number.boolValue))
                    } else {
                        resumeOnce(with: .failure(PreventSleepError.missingField))
                    }
                }
            }
        }
    }

    public func setPreventSleep(_ enabled: Bool, timeoutSeconds: Double = 10.0) async throws -> Bool {
        try await withTimeout(seconds: timeoutSeconds) { [self] in
            let conn = createConnection()
            defer { conn.invalidate() }

            return try await withCheckedThrowingContinuation { continuation in
                let lock = NSLock()
                var hasResumed = false

                func resumeOnce(with result: Result<Bool, Error>) {
                    lock.lock()
                    defer { lock.unlock() }
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(with: result)
                    }
                }

                guard let proxy = conn.remoteObjectProxyWithErrorHandler({ error in
                    resumeOnce(with: .failure(PreventSleepError.helperUnreachable(error.localizedDescription)))
                }) as? PreventSleepXPCProtocol else {
                    resumeOnce(with: .failure(PreventSleepError.helperUnreachable("Could not obtain remote proxy")))
                    return
                }

                proxy.setPreventSleep(enabled) { number, errorString in
                    if let errorString = errorString {
                        resumeOnce(with: .failure(PreventSleepError.commandFailed(exitCode: -1, message: String(errorString))))
                    } else if let number = number {
                        resumeOnce(with: .success(number.boolValue))
                    } else {
                        resumeOnce(with: .failure(PreventSleepError.missingField))
                    }
                }
            }
        }
    }

    private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw PreventSleepError.timedOut
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
