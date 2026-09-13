import Foundation

public actor StateCoordinator {
    public typealias FetchHandler = @Sendable () async throws -> Bool
    public typealias MutateHandler = @Sendable (Bool) async throws -> Bool

    private let fetchHandler: FetchHandler
    private let mutateHandler: MutateHandler

    public private(set) var currentState: OperationalState = .reading
    private var isMutating = false
    private var isRefreshing = false
    private var stateChangeListeners: [@Sendable (OperationalState) -> Void] = []

    public init(
        fetchHandler: @escaping FetchHandler,
        mutateHandler: @escaping MutateHandler
    ) {
        self.fetchHandler = fetchHandler
        self.mutateHandler = mutateHandler
    }

    public func addListener(_ listener: @escaping @Sendable (OperationalState) -> Void) {
        stateChangeListeners.append(listener)
        listener(currentState)
    }

    private func transition(to newState: OperationalState) {
        guard currentState != newState else { return }
        let old = currentState
        currentState = newState
        AppLogger.shared.info("Coordinator", "🔄 State changed: \(old) -> \(newState)")
        for listener in stateChangeListeners {
            listener(newState)
        }
    }

    public func refresh() async {
        guard !isMutating else {
            AppLogger.shared.trace("Coordinator", "Skipping refresh because mutation is in flight")
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let active = try await fetchHandler()
            if !isMutating {
                transition(to: .ready(preventSleep: active))
            }
        } catch PreventSleepError.helperNotInstalled {
            if !isMutating {
                transition(to: .setupRequired)
            }
        } catch let error as PreventSleepError {
            if !isMutating {
                AppLogger.shared.warning("Coordinator", "Refresh reported error: \(error.localizedDescription)")
                transition(to: .unavailable(reason: error.localizedDescription))
            }
        } catch {
            if !isMutating {
                AppLogger.shared.warning("Coordinator", "Refresh reported unexpected error: \(error.localizedDescription)")
                transition(to: .unavailable(reason: error.localizedDescription))
            }
        }
    }

    public func toggle() async {
        guard !isMutating else {
            AppLogger.shared.warning("Coordinator", "Toggle ignored: mutation already in flight")
            return
        }

        guard case .ready(let currentVal) = currentState else {
            AppLogger.shared.info("Coordinator", "Toggle clicked while in state \(currentState). Triggering refresh.")
            await refresh()
            return
        }

        let target = !currentVal
        AppLogger.shared.info("Coordinator", "⚡ Toggle clicked: Current = \(currentVal), Requesting Target = \(target)")
        isMutating = true
        transition(to: .changing(target: target))

        do {
            let confirmed = try await mutateHandler(target)
            isMutating = false
            AppLogger.shared.info("Coordinator", "✅ Toggle successful. Confirmed value = \(confirmed)")
            transition(to: .ready(preventSleep: confirmed))
        } catch let error as PreventSleepError {
            isMutating = false
            AppLogger.shared.error("Coordinator", "❌ Toggle failed: \(error.localizedDescription)")
            transition(to: .unavailable(reason: error.localizedDescription))
        } catch {
            isMutating = false
            AppLogger.shared.error("Coordinator", "❌ Toggle failed with unexpected error: \(error.localizedDescription)")
            transition(to: .unavailable(reason: error.localizedDescription))
        }
    }

    public func forceSet(_ enabled: Bool) async throws -> Bool {
        guard !isMutating else {
            AppLogger.shared.warning("Coordinator", "forceSet ignored: mutation already in flight")
            throw PreventSleepError.commandFailed(exitCode: -1, message: "Mutation already in progress")
        }
        AppLogger.shared.info("Coordinator", "ForceSet requested: \(enabled)")
        isMutating = true
        transition(to: .changing(target: enabled))

        do {
            let confirmed = try await mutateHandler(enabled)
            isMutating = false
            AppLogger.shared.info("Coordinator", "✅ ForceSet confirmed = \(confirmed)")
            transition(to: .ready(preventSleep: confirmed))
            return confirmed
        } catch {
            isMutating = false
            AppLogger.shared.error("Coordinator", "❌ ForceSet failed: \(error.localizedDescription)")
            transition(to: .unavailable(reason: error.localizedDescription))
            throw error
        }
    }
}
