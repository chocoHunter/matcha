import Foundation

enum CaffeineMode: Int, CaseIterable {
    case off = 0
    case awake        // caffeinate -i
    case screenOn     // caffeinate -d
    case extreme      // caffeinate -i -s
    case timed        // caffeinate -i -t <seconds>

    var displayName: String {
        switch self {
        case .off: return "关闭"
        case .awake: return "清醒模式"
        case .screenOn: return "屏幕常亮"
        case .extreme: return "极致模式"
        case .timed: return "定时模式"
        }
    }

    func arguments(timerSeconds: Int? = nil) -> [String] {
        switch self {
        case .off:
            return []
        case .awake:
            return ["-i"]
        case .screenOn:
            return ["-d"]
        case .extreme:
            return ["-i", "-s"]
        case .timed:
            guard let seconds = timerSeconds else { return ["-i"] }
            return ["-i", "-t", "\(seconds)"]
        }
    }
}

class CaffeinateManager {
    static let shared = CaffeinateManager()

    private var process: Process?
    private(set) var currentMode: CaffeineMode = .off
    private(set) var startTime: Date?
    private var timerDuration: Int?  // Total duration in seconds for timed mode

    var isRunning: Bool {
        return process != nil
    }

    var elapsedTime: TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    /// Remaining time in seconds for timed mode, nil if not in timed mode
    var remainingTime: TimeInterval? {
        guard currentMode == .timed, let duration = timerDuration else { return nil }
        let remaining = TimeInterval(duration) - elapsedTime
        return remaining > 0 ? remaining : 0
    }

    /// Format remaining time as string
    var remainingTimeString: String? {
        guard let remaining = remainingTime else { return nil }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start(mode: CaffeineMode, timerSeconds: Int? = nil) {
        // Record today's usage before starting new session
        if isRunning {
            HistoryManager.shared.addUsage(seconds: Int(elapsedTime))
        }

        stop()

        guard mode != .off else { return }

        timerDuration = mode == .timed ? timerSeconds : nil

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        task.arguments = mode.arguments(timerSeconds: timerSeconds)

        do {
            try task.run()
            process = task
            currentMode = mode
            startTime = Date()
            NotificationCenter.default.post(name: .caffeineStateChanged, object: nil)
        } catch {
            print("Failed to start caffeinate: \(error)")
        }
    }

    func stop() {
        // Record usage when stopping
        if let start = startTime {
            HistoryManager.shared.addUsage(seconds: Int(Date().timeIntervalSince(start)))
        }

        process?.terminate()
        process = nil
        currentMode = .off
        startTime = nil
        timerDuration = nil
        NotificationCenter.default.post(name: .caffeineStateChanged, object: nil)
    }
}

extension Notification.Name {
    static let caffeineStateChanged = Notification.Name("caffeineStateChanged")
}
