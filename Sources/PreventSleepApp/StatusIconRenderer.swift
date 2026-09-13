import AppKit
import PreventSleepCore

public struct StatusPresentation: Equatable, Sendable {
    public let symbolName: String
    public let tooltip: String
    public let accessibilityLabel: String

    public static func forState(_ state: OperationalState) -> StatusPresentation {
        switch state {
        case .ready(let preventSleep):
            if preventSleep {
                return StatusPresentation(
                    symbolName: "cup.and.saucer.fill",
                    tooltip: "Prevent Sleep: On",
                    accessibilityLabel: "Prevent Sleep: On"
                )
            } else {
                return StatusPresentation(
                    symbolName: "cup.and.saucer",
                    tooltip: "Prevent Sleep: Off",
                    accessibilityLabel: "Prevent Sleep: Off"
                )
            }
        case .changing:
            return StatusPresentation(
                symbolName: "arrow.triangle.2.circlepath",
                tooltip: "Changing sleep setting...",
                accessibilityLabel: "Changing sleep setting"
            )
        case .unavailable:
            return StatusPresentation(
                symbolName: "exclamationmark.triangle",
                tooltip: "Sleep setting unavailable",
                accessibilityLabel: "Sleep setting unavailable"
            )
        case .setupRequired:
            return StatusPresentation(
                symbolName: "gearshape.fill",
                tooltip: "Setup required",
                accessibilityLabel: "Prevent sleep setup required"
            )
        case .reading:
            return StatusPresentation(
                symbolName: "arrow.clockwise",
                tooltip: "Checking sleep setting...",
                accessibilityLabel: "Checking sleep setting"
            )
        case .removing:
            return StatusPresentation(
                symbolName: "trash",
                tooltip: "Removing helper...",
                accessibilityLabel: "Removing helper"
            )
        }
    }

    public var image: NSImage? {
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityLabel) {
            image.isTemplate = true
            return image
        }
        let fallback = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: accessibilityLabel)
            ?? NSImage(systemSymbolName: "gearshape", accessibilityDescription: accessibilityLabel)
        fallback?.isTemplate = true
        return fallback
    }
}
