import Foundation

public enum PreventSleepSecurity: Sendable {
    public static let teamID = "N4BDK3Z362"
    public static let appIdentifier = "com.sramzz.mac-no-sleep"
    public static let helperIdentifier = "com.sramzz.mac-no-sleep.helper"

    /// Requirement enforced by the helper daemon on all incoming client connections.
    /// Requires Apple cryptographic anchor, app bundle ID, and matching developer Team ID.
    public static let clientRequirement =
        "anchor apple generic and identifier \"\(appIdentifier)\" and certificate leaf[subject.OU] = \"\(teamID)\""

    /// Requirement enforced by the client app when establishing connection to the helper daemon.
    /// Requires Apple cryptographic anchor, helper bundle ID, and matching developer Team ID.
    public static let helperRequirement =
        "anchor apple generic and identifier \"\(helperIdentifier)\" and certificate leaf[subject.OU] = \"\(teamID)\""
}

public enum PreventSleepBuildInfo: Sendable {
    public static let version = "1.0.0"
    public static let buildNumber = "100"
    public static let displayVersion = "1.0.0 (100)"
}
