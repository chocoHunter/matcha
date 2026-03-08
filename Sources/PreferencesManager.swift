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
