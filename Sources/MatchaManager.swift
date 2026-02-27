import Foundation

enum MatchaMode: Int, CaseIterable {
    case off = 0
    case awake        // matcha -i
    case screenOn     // matcha -d
    case extreme      // matcha -i -s
    case timed        // matcha -i -t <seconds>

    var displayName: String {
        switch self {
        case .off: return "关闭"
        case .awake: return "阻止睡眠"
        case .screenOn: return "屏幕常亮"
        case .extreme: return "合盖不睡"
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

class MatchaManager {
    static let shared = MatchaManager()

    private var process: Process?
    private(set) var currentMode: MatchaMode = .off
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

    func start(mode: MatchaMode, timerSeconds: Int? = nil) {
        // Stop any existing session (will record usage in stop())
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
            NotificationCenter.default.post(name: .matchaStateChanged, object: nil)
        } catch {
            print("Failed to start matcha: \(error)")
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
        NotificationCenter.default.post(name: .matchaStateChanged, object: nil)
    }
}

extension Notification.Name {
    static let matchaStateChanged = Notification.Name("matchaStateChanged")
}
