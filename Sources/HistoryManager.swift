import Foundation

class HistoryManager {
    static let shared = HistoryManager()

    private let defaults = UserDefaults.standard
    private let dateKey = "usageDate"
    private let secondsKey = "todayUsageSeconds"

    private var todayUsageSeconds: Int {
        get {
            // Check if it's a new day
            let today = dateString
            if defaults.string(forKey: dateKey) != today {
                defaults.set(today, forKey: dateKey)
                defaults.set(0, forKey: secondsKey)
                return 0
            }
            return defaults.integer(forKey: secondsKey)
        }
        set {
            defaults.set(newValue, forKey: secondsKey)
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private init() {
        // Initialize for today
        _ = todayUsageSeconds
    }

    /// Add usage seconds to today's total
    func addUsage(seconds: Int) {
        guard seconds > 0 else { return }
        todayUsageSeconds += seconds
    }

    /// Get today's total usage in seconds
    func getTodayUsage() -> Int {
        return todayUsageSeconds
    }

    /// Get formatted today's usage string
    func getTodayUsageString() -> String {
        let seconds = getTodayUsage()
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours) 小时 \(minutes) 分钟"
        } else {
            return "\(minutes) 分钟"
        }
    }

    /// Reset today's usage (for testing)
    func resetToday() {
        todayUsageSeconds = 0
    }
}
