import Foundation

class PreferencesManager {
    static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let batteryThreshold = "batteryThreshold"
        static let launchAtLogin = "launchAtLogin"
        static let lastMode = "lastMode"
    }

    var batteryThreshold: Int {
        get {
            let value = defaults.integer(forKey: Keys.batteryThreshold)
            return value == 0 ? 20 : value
        }
        set { defaults.set(newValue, forKey: Keys.batteryThreshold) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }

    var lastMode: Int {
        get { defaults.integer(forKey: Keys.lastMode) }
        set { defaults.set(newValue, forKey: Keys.lastMode) }
    }

    private init() {}
}
