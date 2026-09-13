import Foundation

public struct PowerSettingParser: Sendable {
    private static let regex: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: #"^\s*SleepDisabled\s+(\S+)"#,
                options: [.anchorsMatchLines]
            )
        } catch {
            fatalError("Failed to compile regex: \(error)")
        }
    }()

    public static func parseSleepDisabled(from output: String) throws(PreventSleepError) -> Bool {
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard let match = regex.firstMatch(in: output, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: output) else {
            throw .missingField
        }

        let valueString = String(output[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        switch valueString {
        case "1":
            return true
        case "0":
            return false
        default:
            throw .malformedOutput("Unrecognized SleepDisabled value: \(valueString)")
        }
    }
}
