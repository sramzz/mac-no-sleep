import Foundation

public struct BatteryGuard: Sendable {
    public static let defaultThresholdPercent: Int = 15

    /// Evaluates whether sleep prevention should be automatically disarmed to protect battery health.
    public static func shouldDisarm(
        isCharging: Bool,
        batteryPercent: Int,
        threshold: Int = defaultThresholdPercent,
        isPreventingSleep: Bool
    ) -> Bool {
        guard isPreventingSleep else { return false }
        guard !isCharging else { return false }
        return batteryPercent <= threshold
    }
}
