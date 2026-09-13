import Foundation
import ServiceManagement

public final class AppServiceManager: @unchecked Sendable {
    public static let shared = AppServiceManager()

    public static let helperPlistName = "com.sramzz.mac-no-sleep.helper.plist"
    private let daemonService: SMAppService
    private let loginService: SMAppService

    public init() {
        self.daemonService = SMAppService.daemon(plistName: Self.helperPlistName)
        self.loginService = SMAppService.mainApp
    }

    public var daemonStatus: SMAppService.Status {
        daemonService.status
    }

    public var isDaemonApproved: Bool {
        daemonService.status == .enabled
    }

    public var isLoginItemEnabled: Bool {
        loginService.status == .enabled
    }

    public func registerDaemon() throws {
        try daemonService.register()
    }

    public func unregisterDaemon() throws {
        try daemonService.unregister()
    }

    public func setLoginLaunch(enabled: Bool) throws {
        if enabled {
            try loginService.register()
        } else {
            try loginService.unregister()
        }
    }

    public func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
