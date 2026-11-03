import Testing
@testable import PreventSleepCore

@Suite("BatteryGuard Tests")
struct BatteryGuardTests {

    @Test("Does not disarm when already OFF")
    func doesNotDisarmWhenAlreadyOff() {
        let disarm = BatteryGuard.shouldDisarm(
            isCharging: false,
            batteryPercent: 10,
            threshold: 15,
            isPreventingSleep: false
        )
        #expect(!disarm)
    }

    @Test("Does not disarm when charging regardless of percentage")
    func doesNotDisarmWhenCharging() {
        let disarm = BatteryGuard.shouldDisarm(
            isCharging: true,
            batteryPercent: 5,
            threshold: 15,
            isPreventingSleep: true
        )
        #expect(!disarm)
    }

    @Test("Does not disarm when battery is above threshold")
    func doesNotDisarmAboveThreshold() {
        let disarm = BatteryGuard.shouldDisarm(
            isCharging: false,
            batteryPercent: 50,
            threshold: 15,
            isPreventingSleep: true
        )
        #expect(!disarm)
    }

    @Test("Disarms when battery is exactly at threshold while discharging")
    func disarmsAtThreshold() {
        let disarm = BatteryGuard.shouldDisarm(
            isCharging: false,
            batteryPercent: 15,
            threshold: 15,
            isPreventingSleep: true
        )
        #expect(disarm)
    }

    @Test("Disarms when battery is below threshold while discharging")
    func disarmsBelowThreshold() {
        let disarm = BatteryGuard.shouldDisarm(
            isCharging: false,
            batteryPercent: 8,
            threshold: 15,
            isPreventingSleep: true
        )
        #expect(disarm)
    }
}
