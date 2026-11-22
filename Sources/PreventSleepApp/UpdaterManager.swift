import AppKit
import PreventSleepCore

#if canImport(Sparkle)
import Sparkle
#endif

/// Coordinates in-app software updates via Sparkle 2 (or fallback GitHub Releases link in SwiftPM builds).
@MainActor
public final class UpdaterManager: NSObject {
    public static let shared = UpdaterManager()

    private static let fallbackReleasesURL = URL(string: "https://github.com/sramzz/mac-no-sleep/releases/latest")!

    #if canImport(Sparkle)
    private let updaterController: SPUStandardUpdaterController
    private let hasPublicKey: Bool
    #endif

    private override init() {
        #if canImport(Sparkle)
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        let validKey = key?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        self.hasPublicKey = validKey
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: validKey,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        if !validKey {
            AppLogger.shared.warning("Updater", "SUPublicEDKey missing from Info.plist; Sparkle auto-updater not started.")
        }
        #else
        super.init()
        #endif
    }

    /// Presents the Sparkle update UI (activating the LSUIElement app so dialogs come to the front).
    public func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        #if canImport(Sparkle)
        if hasPublicKey {
            AppLogger.shared.info("Updater", "Checking for updates via Sparkle...")
            updaterController.checkForUpdates(nil)
            return
        }
        #endif
        AppLogger.shared.info("Updater", "Opening releases page in default browser.")
        NSWorkspace.shared.open(Self.fallbackReleasesURL)
    }
}
