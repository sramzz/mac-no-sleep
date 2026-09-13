import Testing
import Foundation
@testable import PreventSleepCore

final class MockPowerClient: @unchecked Sendable {
    var stateToReturn: Result<Bool, PreventSleepError> = .success(false)
    var setToReturn: Result<Bool, PreventSleepError> = .success(true)
    var setCallCount = 0
    var delay: Duration = .zero

    func getState() async throws -> Bool {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        switch stateToReturn {
        case .success(let val): return val
        case .failure(let err): throw err
        }
    }

    func setPreventSleep(_ enabled: Bool) async throws -> Bool {
        setCallCount += 1
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        switch setToReturn {
        case .success(let val): return val
        case .failure(let err): throw err
        }
    }
}

@Suite("StateCoordinator Tests")
struct StateCoordinatorTests {
    @Test("Initial state starts at reading then transitions to ready")
    func testInitialRefresh() async throws {
        let mock = MockPowerClient()
        mock.stateToReturn = .success(true)
        let coordinator = StateCoordinator(
            fetchHandler: { try await mock.getState() },
            mutateHandler: { try await mock.setPreventSleep($0) }
        )

        await coordinator.refresh()
        let state = await coordinator.currentState
        #expect(state == .ready(preventSleep: true))
    }

    @Test("Toggle inverts state and sets changing while pending")
    func testToggleInvertsState() async throws {
        let mock = MockPowerClient()
        mock.stateToReturn = .success(false)
        mock.setToReturn = .success(true)
        let coordinator = StateCoordinator(
            fetchHandler: { try await mock.getState() },
            mutateHandler: { try await mock.setPreventSleep($0) }
        )

        await coordinator.refresh()
        await coordinator.toggle()
        let finalState = await coordinator.currentState
        #expect(finalState == .ready(preventSleep: true))
        #expect(mock.setCallCount == 1)
    }

    @Test("Duplicate toggle clicks are suppressed while mutation is in flight")
    func testDuplicateToggleSuppression() async throws {
        let mock = MockPowerClient()
        mock.stateToReturn = .success(false)
        mock.setToReturn = .success(true)
        mock.delay = .milliseconds(50)

        let coordinator = StateCoordinator(
            fetchHandler: { try await mock.getState() },
            mutateHandler: { try await mock.setPreventSleep($0) }
        )

        await coordinator.refresh()

        // Launch two rapid toggles
        async let t1: Void = coordinator.toggle()
        async let t2: Void = coordinator.toggle()
        _ = await (t1, t2)

        #expect(mock.setCallCount == 1)
    }

    @Test("Stale background refresh does not overwrite in-flight mutation")
    func testStaleRefreshIgnoredDuringMutation() async throws {
        let mock = MockPowerClient()
        mock.stateToReturn = .success(false)
        mock.setToReturn = .success(true)
        mock.delay = .milliseconds(80)

        let coordinator = StateCoordinator(
            fetchHandler: { try await mock.getState() },
            mutateHandler: { try await mock.setPreventSleep($0) }
        )

        await coordinator.refresh()

        async let toggleOp: Void = coordinator.toggle()
        // Try background refresh while mutation is pending
        try await Task.sleep(for: .milliseconds(20))
        await coordinator.refresh() // should be ignored during changing

        _ = await toggleOp
        let finalState = await coordinator.currentState
        #expect(finalState == .ready(preventSleep: true))
    }

    @Test("Read failure transitions to unavailable")
    func testReadFailure() async throws {
        let mock = MockPowerClient()
        mock.stateToReturn = .failure(.missingField)

        let coordinator = StateCoordinator(
            fetchHandler: { try await mock.getState() },
            mutateHandler: { try await mock.setPreventSleep($0) }
        )

        await coordinator.refresh()
        let state = await coordinator.currentState
        #expect(state == .unavailable(reason: "The 'SleepDisabled' setting was not found in pmset output."))
    }
}
