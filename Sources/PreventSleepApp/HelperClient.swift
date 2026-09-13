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
        AppLogger.shared.debug("HelperClient", "getState requested (timeout: \(timeoutSeconds)s)")
        let conn = createConnection()
        return try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var hasResumed = false

            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer.schedule(deadline: .now() + timeoutSeconds)

            func resumeOnce(with result: Result<Bool, Error>) {
                lock.lock()
                defer { lock.unlock() }
                if !hasResumed {
                    hasResumed = true
                    timer.cancel()
                    conn.invalidate()
                    continuation.resume(with: result)
                }
            }

            timer.setEventHandler {
                AppLogger.shared.error("HelperClient", "⏱️ getState timed out after \(timeoutSeconds)s")
                resumeOnce(with: .failure(PreventSleepError.timedOut))
            }
            timer.resume()

            conn.interruptionHandler = {
                AppLogger.shared.warning("HelperClient", "⚠️ XPC connection interrupted in getState")
                resumeOnce(with: .failure(PreventSleepError.helperUnreachable("XPC connection interrupted")))
            }
            conn.invalidationHandler = {
                AppLogger.shared.warning("HelperClient", "⚠️ XPC connection invalidated in getState")
                resumeOnce(with: .failure(PreventSleepError.helperUnreachable("XPC connection invalidated")))
            }
            conn.resume()

            guard let proxy = conn.remoteObjectProxyWithErrorHandler({ error in
                AppLogger.shared.error("HelperClient", "❌ XPC error in getState: \(error.localizedDescription)")
                resumeOnce(with: .failure(PreventSleepError.helperUnreachable(error.localizedDescription)))
            }) as? PreventSleepXPCProtocol else {
                AppLogger.shared.error("HelperClient", "❌ Could not cast remote object proxy to PreventSleepXPCProtocol")
                resumeOnce(with: .failure(PreventSleepError.helperUnreachable("Could not obtain remote proxy")))
                return
            }

            proxy.getState { number, errorString in
                if let errorString = errorString {
                    AppLogger.shared.error("HelperClient", "❌ getState returned error string: \(errorString)")
                    resumeOnce(with: .failure(PreventSleepError.commandFailed(exitCode: -1, message: String(errorString))))
                } else if let number = number {
                    AppLogger.shared.debug("HelperClient", "📥 getState returned success: \(number.boolValue)")
                    resumeOnce(with: .success(number.boolValue))
                } else {
                    AppLogger.shared.error("HelperClient", "❌ getState returned neither number nor error")
                    resumeOnce(with: .failure(PreventSleepError.missingField))
                }
            }
        }
    }

    public func setPreventSleep(_ enabled: Bool, timeoutSeconds: Double = 10.0) async throws -> Bool {
        AppLogger.shared.info("HelperClient", "📡 Sending XPC request: setPreventSleep(\(enabled)) (timeout: \(timeoutSeconds)s)...")
        let conn = createConnection()
        return try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var hasResumed = false

            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer.schedule(deadline: .now() + timeoutSeconds)

            func resumeOnce(with result: Result<Bool, Error>) {
                lock.lock()
                defer { lock.unlock() }
                if !hasResumed {
                    hasResumed = true
                    timer.cancel()
                    conn.invalidate()
                    continuation.resume(with: result)
                }
            }

            timer.setEventHandler {
                AppLogger.shared.error("HelperClient", "⏱️ setPreventSleep(\(enabled)) timed out after \(timeoutSeconds)s")
                resumeOnce(with: .failure(PreventSleepError.timedOut))
            }
            timer.resume()

            conn.interruptionHandler = {
                AppLogger.shared.warning("HelperClient", "⚠️ XPC connection interrupted in setPreventSleep(\(enabled))")
                resumeOnce(with: .failure(PreventSleepError.helperUnreachable("XPC connection interrupted")))
            }
            conn.invalidationHandler = {
                AppLogger.shared.warning("HelperClient", "⚠️ XPC connection invalidated in setPreventSleep(\(enabled))")
                resumeOnce(with: .failure(PreventSleepError.helperUnreachable("XPC connection invalidated")))
            }
            conn.resume()

            guard let proxy = conn.remoteObjectProxyWithErrorHandler({ error in
                AppLogger.shared.error("HelperClient", "❌ XPC error handler fired for setPreventSleep(\(enabled)): \(error.localizedDescription)")
                resumeOnce(with: .failure(PreventSleepError.helperUnreachable(error.localizedDescription)))
            }) as? PreventSleepXPCProtocol else {
                AppLogger.shared.error("HelperClient", "❌ Could not obtain remote proxy for setPreventSleep")
                resumeOnce(with: .failure(PreventSleepError.helperUnreachable("Could not obtain remote proxy")))
                return
            }

            proxy.setPreventSleep(enabled) { number, errorString in
                if let errorString = errorString {
                    AppLogger.shared.error("HelperClient", "❌ setPreventSleep(\(enabled)) reply error: \(errorString)")
                    resumeOnce(with: .failure(PreventSleepError.commandFailed(exitCode: -1, message: String(errorString))))
                } else if let number = number {
                    AppLogger.shared.info("HelperClient", "📥 setPreventSleep(\(enabled)) reply confirmed: \(number.boolValue)")
                    resumeOnce(with: .success(number.boolValue))
                } else {
                    AppLogger.shared.error("HelperClient", "❌ setPreventSleep(\(enabled)) returned neither value nor error")
                    resumeOnce(with: .failure(PreventSleepError.missingField))
                }
            }
        }
    }
}
