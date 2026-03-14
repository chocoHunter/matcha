import Foundation
import ServiceManagement

class PreferencesManager {
    static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let batteryThreshold = "batteryThreshold"
        static let launchAtLogin = "launchAtLogin"
        static let lastMode = "lastMode"
        static let batterySleepEnabled = "batterySleepEnabled"
        static let batterySleepOverrideActive = "batterySleepOverrideActive"
        static let batterySleepSnapshotSleep = "batterySleepSnapshotSleep"
        static let batterySleepSnapshotDisablesleep = "batterySleepSnapshotDisablesleep"
    }

    var batteryThreshold: Int {
        get {
            return defaults.integer(forKey: Keys.batteryThreshold)
        }
        set { defaults.set(newValue, forKey: Keys.batteryThreshold) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
    }

    var lastMode: Int {
        get { defaults.integer(forKey: Keys.lastMode) }
        set { defaults.set(newValue, forKey: Keys.lastMode) }
    }

    /// Whether to allow lid closed mode on battery power
    var batterySleepEnabled: Bool {
        get { defaults.bool(forKey: Keys.batterySleepEnabled) }
        set { defaults.set(newValue, forKey: Keys.batterySleepEnabled) }
    }

    /// Whether this app currently has an active pmset override on battery profile
    var batterySleepOverrideActive: Bool {
        get { defaults.bool(forKey: Keys.batterySleepOverrideActive) }
        set { defaults.set(newValue, forKey: Keys.batterySleepOverrideActive) }
    }

    /// Snapshot of user's original battery sleep settings before override
    var batterySleepSnapshot: (sleep: Int, disablesleep: Int)? {
        get {
            guard defaults.object(forKey: Keys.batterySleepSnapshotSleep) != nil,
                  defaults.object(forKey: Keys.batterySleepSnapshotDisablesleep) != nil else {
                return nil
            }

            return (
                sleep: defaults.integer(forKey: Keys.batterySleepSnapshotSleep),
                disablesleep: defaults.integer(forKey: Keys.batterySleepSnapshotDisablesleep)
            )
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: Keys.batterySleepSnapshotSleep)
                defaults.removeObject(forKey: Keys.batterySleepSnapshotDisablesleep)
                return
            }

            defaults.set(newValue.sleep, forKey: Keys.batterySleepSnapshotSleep)
            defaults.set(newValue.disablesleep, forKey: Keys.batterySleepSnapshotDisablesleep)
        }
    }

    private init() {
        // Apply launch at login on init
        if launchAtLogin {
            if !setLaunchAtLogin(true) {
                defaults.set(false, forKey: Keys.launchAtLogin)
            }
        }
    }

    @discardableResult
    func setLaunchAtLogin(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                defaults.set(enabled, forKey: Keys.launchAtLogin)
                return true
            } catch {
                print("Failed to update launch at login: \(error)")
                return false
            }
        }
        defaults.set(enabled, forKey: Keys.launchAtLogin)
        return true
    }
}
