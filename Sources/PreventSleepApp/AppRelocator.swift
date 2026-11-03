import AppKit
import Foundation
import PreventSleepCore

@MainActor
public enum AppRelocator {
    /// Checks the current application location and prompts the user to move/copy to /Applications if needed.
    /// Returns `true` if relocation was performed (and the app is terminating), or `false` to continue normal startup.
    @discardableResult
    public static func checkLocationAndPrompt() -> Bool {
        let bundleURL = Bundle.main.bundleURL

        // Skip if running from Xcode DerivedData, build directories, or command-line flags
        let bundlePath = bundleURL.path
        if bundlePath.contains("/DerivedData/") ||
           bundlePath.contains("/.build/") ||
           bundlePath.contains("/build/") ||
           CommandLine.arguments.contains("--no-relocate") ||
           CommandLine.arguments.contains("--toggle") ||
           CommandLine.arguments.contains("-t") ||
           CommandLine.arguments.contains("--version") ||
           CommandLine.arguments.contains("-v") ||
           CommandLine.arguments.contains("--test-helper") ||
           CommandLine.arguments.contains("--register") ||
           CommandLine.arguments.contains("--unregister") {
            return false
        }

        // Check if already in /Applications, /Applications/Utilities, or ~/Applications
        if isInsideApplicationsFolder(bundleURL: bundleURL) {
            return false
        }

        // Running outside Applications (e.g. ~/Downloads or mounted DMG)
        let isDiskImage = bundlePath.hasPrefix("/Volumes/")
        AppLogger.shared.info("AppRelocator", "Application running outside Applications folder (\(bundlePath)). Prompting user for relocation.")

        let alert = NSAlert()
        alert.messageText = isDiskImage ? "Copy to Applications Folder?" : "Move to Applications Folder?"
        if isDiskImage {
            alert.informativeText = "Prevent Sleep needs to run from your Applications folder so that its background service can manage system settings reliably.\n\nWould you like to copy Prevent Sleep to Applications and open it from there?"
        } else {
            alert.informativeText = "Prevent Sleep needs to run from your Applications folder so that its background service can manage system settings reliably.\n\nWould you like to move Prevent Sleep to Applications now?"
        }

        alert.addButton(withTitle: isDiskImage ? "Copy to Applications Folder" : "Move to Applications Folder")
        alert.addButton(withTitle: "Do Not Move")
        alert.alertStyle = .informational

        // Ensure alert displays prominently
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        guard response == .alertFirstButtonReturn else {
            AppLogger.shared.info("AppRelocator", "User chose not to move application.")
            return false
        }

        return performRelocation(from: bundleURL, isDiskImage: isDiskImage)
    }

    private static func isInsideApplicationsFolder(bundleURL: URL) -> Bool {
        let path = bundleURL.resolvingSymlinksInPath().path
        let standardApps = "/Applications/"
        let utilityApps = "/Applications/Utilities/"
        let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path + "/"

        return path.hasPrefix(standardApps) || path.hasPrefix(utilityApps) || path.hasPrefix(userApps)
    }

    private static func performRelocation(from sourceURL: URL, isDiskImage: Bool) -> Bool {
        let fileManager = FileManager.default
        let appName = sourceURL.lastPathComponent
        let targetDirectory = URL(fileURLWithPath: "/Applications")
        let destinationURL = targetDirectory.appendingPathComponent(appName)

        // Verify write access to /Applications
        if !fileManager.isWritableFile(atPath: targetDirectory.path) {
            AppLogger.shared.error("AppRelocator", "/Applications is not writable by current user.")
            let permAlert = NSAlert()
            permAlert.messageText = "Permission Required"
            permAlert.informativeText = "Prevent Sleep cannot write directly to /Applications with your current user account permissions.\n\nPlease drag Prevent Sleep into your Applications folder using Finder."
            permAlert.alertStyle = .warning
            permAlert.runModal()
            return false
        }

        AppLogger.shared.info("AppRelocator", "Relocating from \(sourceURL.path) to \(destinationURL.path)")

        do {
            // If target already exists in /Applications, unregister daemon and remove old bundle
            if fileManager.fileExists(atPath: destinationURL.path) {
                AppLogger.shared.info("AppRelocator", "Existing app found at \(destinationURL.path). Unregistering and replacing...")
                try? AppServiceManager.shared.unregisterDaemon()
                try fileManager.removeItem(at: destinationURL)
            }

            // Copy to /Applications
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            AppLogger.shared.info("AppRelocator", "Successfully copied bundle to \(destinationURL.path)")

            // If not a disk image, clean up the original file from Downloads/Desktop
            if !isDiskImage {
                try? fileManager.removeItem(at: sourceURL)
            }

            // Refresh LaunchServices registration
            registerWithLaunchServices(at: destinationURL)

            // Spawn the new app from /Applications
            let openProcess = Process()
            openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            openProcess.arguments = [destinationURL.path]
            try openProcess.run()

            // If launched from a DMG, schedule DMG unmount
            if isDiskImage {
                unmountDiskImageAsync(containing: sourceURL)
            }

            // Terminate current instance
            AppLogger.shared.info("AppRelocator", "Relaunch initiated from \(destinationURL.path). Terminating current instance.")
            NSApp.terminate(nil)
            return true
        } catch {
            AppLogger.shared.error("AppRelocator", "Failed to relocate app: \(error.localizedDescription)")
            let errorAlert = NSAlert()
            errorAlert.messageText = "Could Not Move to Applications"
            errorAlert.informativeText = "Error moving application: \(error.localizedDescription)\n\nPlease manually drag Prevent Sleep into your Applications folder."
            errorAlert.alertStyle = .critical
            errorAlert.runModal()
            return false
        }
    }

    private static func registerWithLaunchServices(at url: URL) {
        let lsregisterPath = "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
        if FileManager.default.fileExists(atPath: lsregisterPath) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: lsregisterPath)
            proc.arguments = ["-f", "-R", "-trusted", url.path]
            try? proc.run()
            proc.waitUntilExit()
        }
    }

    private static func unmountDiskImageAsync(containing url: URL) {
        let components = url.pathComponents
        guard components.count >= 3, components[1] == "Volumes" else { return }
        let volumePath = "/Volumes/\(components[2])"

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            proc.arguments = ["detach", volumePath, "-quiet", "-force"]
            try? proc.run()
        }
    }
}
