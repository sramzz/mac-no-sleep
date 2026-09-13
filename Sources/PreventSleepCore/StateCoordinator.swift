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
        currentState = newState
        for listener in stateChangeListeners {
            listener(newState)
        }
    }

    public func refresh() async {
        guard !isMutating else { return }
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
                transition(to: .unavailable(reason: error.localizedDescription))
            }
        } catch {
            if !isMutating {
                transition(to: .unavailable(reason: error.localizedDescription))
            }
        }
    }

    public func toggle() async {
        guard !isMutating else { return }

        guard case .ready(let currentVal) = currentState else {
            // If unavailable or reading, trigger refresh to test connectivity
            await refresh()
            return
        }

        let target = !currentVal
        isMutating = true
        transition(to: .changing(target: target))

        do {
            let confirmed = try await mutateHandler(target)
            isMutating = false
            transition(to: .ready(preventSleep: confirmed))
        } catch let error as PreventSleepError {
            isMutating = false
            transition(to: .unavailable(reason: error.localizedDescription))
        } catch {
            isMutating = false
            transition(to: .unavailable(reason: error.localizedDescription))
        }
    }

    public func forceSet(_ enabled: Bool) async throws -> Bool {
        guard !isMutating else {
            throw PreventSleepError.commandFailed(exitCode: -1, message: "Mutation already in progress")
        }
        isMutating = true
        transition(to: .changing(target: enabled))

        do {
            let confirmed = try await mutateHandler(enabled)
            isMutating = false
            transition(to: .ready(preventSleep: confirmed))
            return confirmed
        } catch {
            isMutating = false
            transition(to: .unavailable(reason: error.localizedDescription))
            throw error
        }
    }
}
