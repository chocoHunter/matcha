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

    private init() {}

    var isRunning: Bool {
        process != nil
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
        let preserveBatteryOverride = BatterySleepOperationPlanner.shouldPreserveOverrideWhenStarting(
            mode: mode,
            batterySleepEnabled: PreferencesManager.shared.batterySleepEnabled
        )
        stop(restoreBatteryOverride: !preserveBatteryOverride) { [weak self] in
            self?.startAfterStop(mode: mode, timerSeconds: timerSeconds)
        }
    }

    func stop(restoreBatteryOverride: Bool = true, completion: (() -> Void)? = nil) {
        recordUsageIfNeeded()

        let finalize: () -> Void = { [weak self] in
            self?.terminateProcessAndResetState()
            completion?()
        }

        guard BatterySleepOperationPlanner.shouldRestoreOverrideOnStop(
            restoreRequested: restoreBatteryOverride,
            overrideActive: PreferencesManager.shared.batterySleepOverrideActive
        ) else {
            finalize()
            return
        }

        restoreBatterySleep { success, error in
            if !success {
                NotificationCenter.default.post(
                    name: .batterySleepRestoreFailed,
                    object: error ?? "Unknown error"
                )
            }
            finalize()
        }
    }

    /// Enable battery sleep mode (allow lid closed on battery)
    /// Requires admin privileges, will prompt user
    func enableBatterySleep(completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            guard let snapshot = self.readCurrentBatterySleepSettings() else {
                DispatchQueue.main.async {
                    completion(false, "无法读取当前电源设置（pmset -g custom）")
                }
                return
            }

            let script = """
            do shell script "pmset -b sleep 0; pmset -b disablesleep 1" with administrator privileges
            """

            self.runAppleScript(script) { success, error in
                if success {
                    PreferencesManager.shared.batterySleepSnapshot = (
                        sleep: snapshot.sleep,
                        disablesleep: snapshot.disablesleep
                    )
                    PreferencesManager.shared.batterySleepOverrideActive = true
                    PreferencesManager.shared.batterySleepEnabled = true
                }
                completion(success, error)
            }
        }
    }

    /// Restore battery sleep settings from snapshot (if any), otherwise only clear disablesleep
    func restoreBatterySleep(completion: @escaping (Bool, String?) -> Void = { _, _ in }) {
        let command = BatterySleepCommandBuilder.restoreCommand(
            snapshot: PreferencesManager.shared.batterySleepSnapshot
        )

        let script = """
        do shell script "\(command)" with administrator privileges
        """

        runAppleScript(script) { success, error in
            if success {
                PreferencesManager.shared.batterySleepOverrideActive = false
                PreferencesManager.shared.batterySleepEnabled = false
                PreferencesManager.shared.batterySleepSnapshot = nil
            }
            completion(success, error)
        }
    }

    func recoverBatterySleepIfNeeded(completion: @escaping (Bool, String?) -> Void) {
        let action = BatterySleepOperationPlanner.recoveryAction(
            batterySleepEnabled: PreferencesManager.shared.batterySleepEnabled,
            overrideActive: PreferencesManager.shared.batterySleepOverrideActive
        )

        if action == .clearStalePreference {
            PreferencesManager.shared.batterySleepEnabled = false
        }

        guard action == .restoreOverride else {
            completion(true, nil)
            return
        }

        restoreBatterySleep(completion: completion)
    }

    private func startAfterStop(mode: MatchaMode, timerSeconds: Int?) {
        guard mode != .off else { return }

        timerDuration = mode == .timed ? timerSeconds : nil

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        task.arguments = mode.arguments(timerSeconds: timerSeconds)
        task.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.handleProcessTermination(process)
            }
        }

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

    private func terminateProcessAndResetState() {
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        currentMode = .off
        startTime = nil
        timerDuration = nil
        NotificationCenter.default.post(name: .matchaStateChanged, object: nil)
    }

    private func recordUsageIfNeeded() {
        guard let start = startTime else { return }
        HistoryManager.shared.addUsage(seconds: Int(Date().timeIntervalSince(start)))
        startTime = nil
    }

    private func runAppleScript(_ script: String, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(&error)

            DispatchQueue.main.async {
                if let error = error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    completion(false, message)
                } else {
                    completion(true, nil)
                }
            }
        }
    }

    private func runCommand(_ executablePath: String, arguments: [String]) -> (output: String, status: Int32)? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executablePath)
        task.arguments = arguments

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = outputPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        return (output, task.terminationStatus)
    }

    func sleepDisplayNow() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            _ = self?.runCommand("/usr/bin/pmset", arguments: ["displaysleepnow"])
        }
    }

    private func readCurrentBatterySleepSettings() -> (sleep: Int, disablesleep: Int)? {
        guard let result = runCommand("/usr/bin/pmset", arguments: ["-g", "custom"]),
              result.status == 0 else {
            return nil
        }

        return BatterySleepSettingsParser.parse(from: result.output)
    }

    private func handleProcessTermination(_ terminatedProcess: Process) {
        guard process === terminatedProcess else { return }

        recordUsageIfNeeded()

        let finalize: () -> Void = { [weak self] in
            self?.process = nil
            self?.currentMode = .off
            self?.timerDuration = nil
            NotificationCenter.default.post(name: .matchaStateChanged, object: nil)
        }

        guard PreferencesManager.shared.batterySleepOverrideActive else {
            finalize()
            return
        }

        restoreBatterySleep { success, error in
            if !success {
                NotificationCenter.default.post(
                    name: .batterySleepRestoreFailed,
                    object: error ?? "Unknown error"
                )
            }
            finalize()
        }
    }
}

extension Notification.Name {
    static let matchaStateChanged = Notification.Name("matchaStateChanged")
    static let batterySleepRestoreFailed = Notification.Name("batterySleepRestoreFailed")
}
