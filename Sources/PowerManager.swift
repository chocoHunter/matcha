import Foundation
import IOKit
import IOKit.ps

class PowerManager {
    static let shared = PowerManager()

    private var timer: Timer?
    var onBatteryLevelChanged: (Int, Bool) -> Void = { _, _ in }
    // (batteryLevel, isCharging)

    private init() {}

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkBattery()
        }
        checkBattery()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first else {
            return
        }

        guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            return
        }

        let currentCapacity = info[kIOPSCurrentCapacityKey as String] as? Int ?? 0
        let isCharging = (info[kIOPSIsChargingKey as String] as? Bool) ?? false

        DispatchQueue.main.async { [weak self] in
            self?.onBatteryLevelChanged(currentCapacity, isCharging)
        }
    }

    func getBatteryInfo() -> (level: Int, isCharging: Bool)? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            return nil
        }

        let level = info[kIOPSCurrentCapacityKey as String] as? Int ?? 0
        let isCharging = (info[kIOPSIsChargingKey as String] as? Bool) ?? false
        return (level, isCharging)
    }

    func isClamshellClosed() -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let value = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Bool else {
            return nil
        }

        return value
    }
}
