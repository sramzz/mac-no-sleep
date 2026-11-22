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
                    symbolName: "StatusIconActive",
                    tooltip: "Prevent Sleep: On",
                    accessibilityLabel: "Prevent Sleep: On"
                )
            } else {
                return StatusPresentation(
                    symbolName: "StatusIconInactive",
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
        if let embeddedBase64 = Self.embeddedStatusIconBase64[symbolName] {
            let image = NSImage(named: NSImage.Name(symbolName))
                ?? Self.decodePNGImage(base64: embeddedBase64)
            if let image {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                image.accessibilityDescription = accessibilityLabel
                return image
            }
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityLabel) {
            image.isTemplate = true
            return image
        }
        let fallback = NSImage(systemSymbolName: "gearshape", accessibilityDescription: accessibilityLabel)
        fallback?.isTemplate = true
        return fallback
    }

    private static func decodePNGImage(base64: String) -> NSImage? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        return NSImage(data: data)
    }

    // Embedded @2x template PNGs used when running outside the app bundle (e.g. `swift test`).
    private static let embeddedStatusIconBase64: [String: String] = [
        "StatusIconActive": "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",
        "StatusIconInactive": "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAJKADAAQAAAABAAAAJAAAAAAJxsHGAAAFDElEQVRYCeWYbWiTVxTHTZMmjTUJiW2SvqRvySauIgo6C51sbnbCViaDsdIvY36YDFQEp+AUP/iCiFNRsEzYZidjW6vbbHXDTlwZgzGQVQYyGDiwa1qGi6TvS21e6u/E55ZYbWNsnvrBC6fn3vOc5/7/OS/3PmqY9wRGYWHhgvz8fJOCzsnJmRgeHo6HQqGRSaN6OAfaaDabT8fj8dUTDPDiBoPBhO0X5g05c0BgKkQcHseRTYlE4n0eBhEv6zZxNMgfvUYgELCPjY1tANhhNBr/BycyOjr6RTgcHhLMkpKS14nOt0w/6e3t3SI2XVMGGRO/fBGgNki9io5ardYWAS4uLhb7p0z/MJlMe8Q2ZwPw5USjB3lbQKWoS0tLO5FbRUVFi1OJ6F5DHo/HTSQ+Q77u6+s7C7iBAt7Jeg3R6yCVbgjX+Xy+lfJM1xqqrq42Dw4ONgO0mpQ1kpp+uusW6+8htAR9B5GgSGq7IFynKyGJTm5u7kUAFwA4ho5A5N1oNCqtbmWdHERMeER6enpu6lrUeXl5RiLyEpGxECGDHIDd3d3SYYl7VHT8W1ZWVk2RHqLVLQLDfCPSTSG/nAmsMRPn6XzdbrefX3+BAl0/Pj5eZrfbPaSkCXEhb7C+PjQ0dGO691Pts+4yr9dbYbFY2gGuJD2dEHuH+SlApFAFy4muSQWdaT4rQpwh5dRHO4CLqJH3OG3XoT+GkMKUa+IE3bNXGdLpx04ZZ4ePFF0kIksBPQroEcAS3NodDofDjX0F9psQfAvbeDoi6vljEaJYS4jCBWQZGw0iz0Kiizr5h/kE+pLNZpP6WYsEXC7XTwMDA9L2aUfGKSsvLy9i1+80MpupmzWszURDLke1H4FJfIRtAL9GfFalZaI5ZHQOVVZWejjUzpOO5wFpJk1Nsg/pe5HC7meaPF/oOg8+ZyGzEFJbqa3LGl5aNVl96TwBLaBm5JulFpAQYLnMNwSDwXZ0sp1kD+XH81pIfwDpY2J/1KFCPKM/h9tCfvE3ONWSil2iIfUf8iH3lRBLDmrLhd85IYPfzkzJqH1m1JzAToA60RPoH5SztDw3tF+tNb8r4od9t7JnqmfssqqqKkcsFmvlF68lGkH0UropTBddGxkZ6UdL3cyji+ycR61Ep4407adm9mVKRPnfV0NEwArwQTa+HolEznE5tjB/jfAf4oWTEGrluY/5ckDDsklBQYENv6/wq4fMAdKUva8/+VyA1A0kSt1cI/SSpsPgJon7/X43KXlOiMiQLz/82rU0HbxnzfJfCASQvwQEfWW67bXP0Dbxg5Sc0lkZD9QQdRGmTi6x+ytSM9zUIWxdqWi09nw+vM6QpjdJ4XHSt4Pnk62f6pu1OaA+IhQkbTHmm9TG2KzYWrQInsD+SEeHej+dnvakJjo1iI0NOA+NJ0mLfHaeISKniUwDhd5EZLbxPKtff/d1mWJPBBoAboaAdJ0QuY0u5PlV5jWQOUU3yd0VU+9kSycJQWAdgJuJxEbAVjH/EuD5GsgO1m2s5XZfTGv/CpkXskVg6j7J/AP4jHaO/Mz8c5wUmT3cVUdIzd+QqefZn/itoI5Sb/ape85qnewyuugq3TQKaCOSh8gH1V7IHFC78++rfrrvR0jVYzPyznm0vp1F6rYjCeRfpFiRSdUVFRVeDtD8VJuuc7ppG2TkUPzd6XQ6dAV7yOYPHIx8//5G+u6QttvcUx38r1b8Ie89Paa7YecaMiP6bQYAAAAASUVORK5CYII="
    ]
}
