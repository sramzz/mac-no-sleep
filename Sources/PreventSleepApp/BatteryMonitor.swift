@preconcurrency import Foundation
@preconcurrency import CoreFoundation
import IOKit.ps
@preconcurrency import UserNotifications
import PreventSleepCore

@MainActor
public final class BatteryMonitor: @unchecked Sendable {
    private var runLoopSource: CFRunLoopSource?
    private let onDisarmRequired: @MainActor () -> Void
    private var isPreventingSleep: Bool = false
    private let threshold: Int

    public init(threshold: Int = BatteryGuard.defaultThresholdPercent, onDisarmRequired: @escaping @MainActor () -> Void) {
        self.threshold = threshold
        self.onDisarmRequired = onDisarmRequired
        startMonitoring()
    }

    public func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
    }

    public func updateSleepState(isPreventing: Bool) {
        self.isPreventingSleep = isPreventing
        evaluateBatteryState()
    }

    private func startMonitoring() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let loopSource = IOPSNotificationCreateRunLoopSource({ info in
            guard let info = info else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(info).takeUnretainedValue()
            Task { @MainActor in
                monitor.evaluateBatteryState()
            }
        }, context)?.takeRetainedValue() {
            self.runLoopSource = loopSource
            CFRunLoopAddSource(CFRunLoopGetMain(), loopSource, .defaultMode)
        }
        evaluateBatteryState()
    }

    public func evaluateBatteryState() {
        guard isPreventingSleep else { return }

        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }

        for ps in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let cur = desc[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let max = desc[kIOPSMaxCapacityKey as String] as? Int ?? 100
            let charging = desc[kIOPSIsChargingKey as String] as? Bool ?? false
            let percent = max > 0 ? (cur * 100) / max : 0

            let disarm = BatteryGuard.shouldDisarm(
                isCharging: charging,
                batteryPercent: percent,
                threshold: threshold,
                isPreventingSleep: isPreventingSleep
            )

            if disarm {
                AppLogger.shared.warning("BatteryMonitor", "Low battery condition detected (\(percent)% <= \(threshold)%). Disarming sleep prevention to protect battery.")
                isPreventingSleep = false
                onDisarmRequired()
                notifyUserOfDisarm(batteryPercent: percent)
                break
            }
        }
    }

    private func notifyUserOfDisarm(batteryPercent: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Prevent Sleep Disabled"
            content.body = "Battery reached \(batteryPercent)%. Normal sleep was restored to protect your laptop from running out of power."
            content.sound = .default

            let request = UNNotificationRequest(identifier: "com.sramzz.mac-no-sleep.low-battery", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
}
