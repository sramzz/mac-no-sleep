import Testing
@testable import PreventSleepCore
@testable import PreventSleepAppLib

@Suite("StatusIconRenderer Tests")
struct StatusIconRendererTests {
    @Test("OperationalState presentation strings")
    func testPresentationStrings() {
        #expect(StatusPresentation.forState(.ready(preventSleep: true)).tooltip == "Prevent Sleep: On")
        #expect(StatusPresentation.forState(.ready(preventSleep: false)).tooltip == "Prevent Sleep: Off")
        #expect(StatusPresentation.forState(.changing(target: true)).tooltip == "Changing sleep setting...")
        #expect(StatusPresentation.forState(.unavailable(reason: "err")).tooltip == "Sleep setting unavailable")
        #expect(StatusPresentation.forState(.setupRequired).tooltip == "Setup required")
        #expect(StatusPresentation.forState(.reading).tooltip == "Checking sleep setting...")
        #expect(StatusPresentation.forState(.removing).tooltip == "Removing helper...")
    }

    @Test("OperationalState accessibility labels")
    func testAccessibilityLabels() {
        #expect(StatusPresentation.forState(.ready(preventSleep: true)).accessibilityLabel == "Prevent Sleep: On")
        #expect(StatusPresentation.forState(.ready(preventSleep: false)).accessibilityLabel == "Prevent Sleep: Off")
        #expect(StatusPresentation.forState(.changing(target: true)).accessibilityLabel == "Changing sleep setting")
        #expect(StatusPresentation.forState(.unavailable(reason: "err")).accessibilityLabel == "Sleep setting unavailable")
    }

    @Test("OperationalState symbol names")
    func testSymbolNames() {
        #expect(StatusPresentation.forState(.ready(preventSleep: true)).symbolName == "cup.and.saucer.fill")
        #expect(StatusPresentation.forState(.ready(preventSleep: false)).symbolName == "cup.and.saucer")
        #expect(StatusPresentation.forState(.changing(target: true)).symbolName == "arrow.triangle.2.circlepath")
        #expect(StatusPresentation.forState(.unavailable(reason: "err")).symbolName == "exclamationmark.triangle")
        #expect(StatusPresentation.forState(.setupRequired).symbolName == "gearshape.fill")
    }

    @Test("Every state produces a valid non-nil NSImage")
    func testAllStatesProduceNonNilImage() {
        let states: [OperationalState] = [
            .ready(preventSleep: true),
            .ready(preventSleep: false),
            .changing(target: true),
            .unavailable(reason: "err"),
            .setupRequired,
            .reading,
            .removing
        ]
        for state in states {
            let presentation = StatusPresentation.forState(state)
            #expect(presentation.image != nil, "Image for \(state) must not be nil")
        }
    }
}
