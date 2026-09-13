import Foundation

@objc public protocol PreventSleepXPCProtocol {
    func getState(withReply reply: @escaping (NSNumber?, NSString?) -> Void)
    func setPreventSleep(_ enabled: Bool, withReply reply: @escaping (NSNumber?, NSString?) -> Void)
}

public enum PreventSleepError: Error, Equatable, Sendable {
    case missingField
    case malformedOutput(String)
    case commandFailed(exitCode: Int32, message: String)
    case mismatchedReadback(expected: Bool, actual: Bool)
    case timedOut
    case unauthorizedClient(String)
    case helperNotInstalled
    case helperUnreachable(String)

    public var localizedDescription: String {
        switch self {
        case .missingField:
            return "The 'SleepDisabled' setting was not found in pmset output."
        case .malformedOutput(let details):
            return "Malformed pmset output: \(details)"
        case .commandFailed(let exitCode, let message):
            return "pmset command failed with exit code \(exitCode): \(message)"
        case .mismatchedReadback(let expected, let actual):
            return "Power setting verification failed: expected \(expected), observed \(actual)."
        case .timedOut:
            return "The operation timed out waiting for a response."
        case .unauthorizedClient(let details):
            return "Connection rejected: \(details)"
        case .helperNotInstalled:
            return "Privileged helper is not installed or requires approval."
        case .helperUnreachable(let message):
            return "Helper is unreachable: \(message)"
        }
    }
}

public enum OperationalState: Equatable, Sendable {
    case setupRequired
    case reading
    case ready(preventSleep: Bool)
    case changing(target: Bool)
    case unavailable(reason: String)
    case removing
}
