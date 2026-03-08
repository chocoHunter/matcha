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
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin()
        }
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
            updateLaunchAtLogin()
        }
    }

    private func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }
}
