import AppKit

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var statusMenuItem: NSMenuItem!
    private var batteryMenuItem: NSMenuItem!
    private var historyMenuItem: NSMenuItem!
    private var stopMenuItem: NSMenuItem!
    private var timerMenuItem: NSMenuItem!
    private var thresholdMenuItem: NSMenuItem!
    private var batterySleepMenuItem: NSMenuItem!
    private var repairSleepMenuItem: NSMenuItem!
    private var awakeMenuItem: NSMenuItem!
    private var screenOnMenuItem: NSMenuItem!
    private var extremeMenuItem: NSMenuItem!
    private var timer: Timer?

    private var selectedMode: MatchaMode = .off
    private var selectedTimerMinutes: Int = 0 // 0 means permanent
    private var isPowerOperationInProgress = false
    private var lastClamshellClosedState: Bool?

    override init() {
        super.init()
        setupStatusItem()
        setupMenu()
        startUpdateTimer()
        setupNotifications()
        attemptStartupBatteryRecoveryIfNeeded()
        updateHistoryDisplay()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon(for: .off)
    }

    private func setupMenu() {
        menu = NSMenu()

        // Status section
        statusMenuItem = NSMenuItem(title: "状态: 关闭", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        batteryMenuItem = NSMenuItem(title: "电池: --%", action: nil, keyEquivalent: "")
        batteryMenuItem.isEnabled = false
        menu.addItem(batteryMenuItem)

        // History section
        historyMenuItem = NSMenuItem(title: "今日累计: 0 分钟", action: nil, keyEquivalent: "")
        historyMenuItem.isEnabled = false
        menu.addItem(historyMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Stop button - default state with checkmark
        stopMenuItem = NSMenuItem(title: "恢复休眠", action: #selector(stopMatcha), keyEquivalent: "")
        stopMenuItem.target = self
        stopMenuItem.state = .on  // Default checked
        stopMenuItem.isEnabled = false
        menu.addItem(stopMenuItem)

        // Mode selection
        awakeMenuItem = NSMenuItem(title: "阻止睡眠", action: #selector(selectAwake), keyEquivalent: "")
        awakeMenuItem.target = self
        menu.addItem(awakeMenuItem)

        screenOnMenuItem = NSMenuItem(title: "屏幕常亮", action: #selector(selectScreenOn), keyEquivalent: "")
        screenOnMenuItem.target = self
        menu.addItem(screenOnMenuItem)

        extremeMenuItem = NSMenuItem(title: "合盖不睡（插电）", action: #selector(selectExtreme), keyEquivalent: "")
        extremeMenuItem.target = self
        menu.addItem(extremeMenuItem)

        // Battery sleep mode toggle (shown next to lid closed option)
        batterySleepMenuItem = NSMenuItem(title: "合盖不睡（电池）", action: #selector(toggleBatterySleep), keyEquivalent: "")
        batterySleepMenuItem.target = self
        menu.addItem(batterySleepMenuItem)

        repairSleepMenuItem = NSMenuItem(title: "修复休眠设置", action: #selector(repairSleepSettings), keyEquivalent: "")
        repairSleepMenuItem.target = self
        menu.addItem(repairSleepMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Settings section - Timer, Battery, Launch at Login
        // Timer submenu - longer time options with permanent
        let timerMenu = NSMenu()
        let permanentItem = NSMenuItem(title: "永久", action: #selector(selectTimer(_:)), keyEquivalent: "")
        permanentItem.target = self
        permanentItem.tag = 0
        timerMenu.addItem(permanentItem)
        for minutes in [15, 30, 60, 120, 180, 240, 360, 480, 720, 1440] {
            let title = minutes >= 60 ? "\(minutes / 60) 小时" : "\(minutes) 分钟"
            let item = NSMenuItem(title: title, action: #selector(selectTimer(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            timerMenu.addItem(item)
        }
        // Custom timer option
        let customTimerItem = NSMenuItem(title: "自定义...", action: #selector(customTimer), keyEquivalent: "")
        customTimerItem.target = self
        timerMenu.addItem(NSMenuItem.separator())
        timerMenu.addItem(customTimerItem)

        timerMenuItem = NSMenuItem(title: "定时恢复: 永久", action: nil, keyEquivalent: "")
        timerMenuItem.submenu = timerMenu
        menu.addItem(timerMenuItem)

        // Battery threshold - off by default
        let thresholdMenu = NSMenu()
        let offItem = NSMenuItem(title: "关闭", action: #selector(selectThreshold(_:)), keyEquivalent: "")
        offItem.target = self
        offItem.tag = 0
        thresholdMenu.addItem(offItem)
        for threshold in [10, 20, 30, 50] {
            let item = NSMenuItem(title: "\(threshold)%", action: #selector(selectThreshold(_:)), keyEquivalent: "")
            item.target = self
            item.tag = threshold
            thresholdMenu.addItem(item)
        }
        // Custom threshold option
        let customThresholdItem = NSMenuItem(title: "自定义...", action: #selector(customThreshold), keyEquivalent: "")
        customThresholdItem.target = self
        thresholdMenu.addItem(NSMenuItem.separator())
        thresholdMenu.addItem(customThresholdItem)

        thresholdMenuItem = NSMenuItem(title: "电量控制: 关闭", action: nil, keyEquivalent: "")
        thresholdMenuItem.submenu = thresholdMenu
        menu.addItem(thresholdMenuItem)

        let launchItem = NSMenuItem(title: "开机自启", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = PreferencesManager.shared.launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "退出程序", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        updatePowerActionAvailability()
    }

    private func startUpdateTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateStatus()
            self?.handleBatterySleepClamshellTransition()
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(matchaStateChanged),
            name: .matchaStateChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batterySleepRestoreFailed(_:)),
            name: .batterySleepRestoreFailed,
            object: nil
        )

        PowerManager.shared.startMonitoring()
        PowerManager.shared.onBatteryLevelChanged = { [weak self] level, isCharging in
            guard let self = self else { return }
            self.updateBatteryDisplay(level: level, isCharging: isCharging)
        }

        updateBatteryDisplay()
    }

    @objc private func batterySleepRestoreFailed(_ notification: Notification) {
        let message = notification.object as? String
        showBatterySleepRestoreFailedAlert(message)
    }

    @objc private func matchaStateChanged() {
        updateIcon(for: MatchaManager.shared.currentMode)
        updateStatus()
        updateModeCheckmarks(selected: MatchaManager.shared.currentMode)
        updatePowerActionAvailability()
    }

    private func updateIcon(for mode: MatchaMode) {
        guard let button = statusItem.button else { return }

        let symbolName: String
        switch mode {
        case .off:
            symbolName = "cup.and.saucer"
        case .awake, .screenOn, .extreme:
            symbolName = "cup.and.saucer.fill"
        case .timed:
            symbolName = "timer"
        }

        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Matcha")
    }

    private func updateStatus() {
        if isPowerOperationInProgress {
            statusMenuItem.title = "状态: 正在切换..."
            return
        }

        let manager = MatchaManager.shared
        if manager.isRunning {
            let elapsed = Int(manager.elapsedTime)
            let hours = elapsed / 3600
            let minutes = (elapsed % 3600) / 60
            let seconds = elapsed % 60

            var timeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)

            // Show remaining time for timed mode
            if let remainingString = manager.remainingTimeString {
                timeString += " [剩余: \(remainingString)]"
            }

            // Show power source info for lid closed mode
            var powerInfo = ""
            if manager.currentMode == .extreme {
                // Show based on user's setting, not actual power state
                let isBatteryMode = PreferencesManager.shared.batterySleepEnabled
                powerInfo = isBatteryMode ? "【电池】" : "【插电】"
            }

            statusMenuItem.title = "状态: \(manager.currentMode.displayName)\(powerInfo) (\(timeString))"
        } else {
            statusMenuItem.title = "状态: 关闭"
            // Update history when stopped
            updateHistoryDisplay()
        }
    }

    private func updateHistoryDisplay() {
        let usageString = HistoryManager.shared.getTodayUsageString()
        historyMenuItem.title = "今日累计: \(usageString)"
    }

    private func updateBatteryDisplay(level: Int? = nil, isCharging: Bool? = nil) {
        let batteryLevel: Int
        let charging: Bool

        if let level, let isCharging {
            batteryLevel = level
            charging = isCharging
        } else if let info = PowerManager.shared.getBatteryInfo() {
            batteryLevel = info.level
            charging = info.isCharging
        } else {
            batteryMenuItem.title = "电池: --%"
            return
        }

        let icon = charging ? "🔌" : "🔋"
        batteryMenuItem.title = "电池: \(batteryLevel)% \(icon)"

        // Auto-stop check - only when threshold > 0 (enabled)
        let threshold = PreferencesManager.shared.batteryThreshold
        if threshold > 0 && !charging && batteryLevel <= threshold && MatchaManager.shared.isRunning && !isPowerOperationInProgress {
            guard beginPowerOperation() else { return }
            MatchaManager.shared.stop { [weak self] in
                self?.endPowerOperation()
            }
        }
    }

    @objc private func selectAwake() {
        startMatcha(mode: .awake)
    }

    @objc private func selectScreenOn() {
        startMatcha(mode: .screenOn)
    }

    @objc private func selectExtreme() {
        startMatcha(mode: .extreme)
    }

    @objc private func stopMatcha() {
        guard beginPowerOperation() else { return }

        MatchaManager.shared.stop { [weak self] in
            self?.clearAllCheckmarks()
            self?.stopMenuItem?.state = .on
            self?.endPowerOperation()
        }
    }

    @objc private func selectTimer(_ sender: NSMenuItem) {
        selectedTimerMinutes = sender.tag
        if sender.tag == 0 {
            timerMenuItem.title = "定时恢复: 永久"
        } else {
            timerMenuItem.title = "定时恢复: \(sender.title)"
        }
        startMatcha(mode: .timed)
    }

    @objc private func customTimer() {
        let alert = NSAlert()
        alert.messageText = "自定义定时"
        alert.informativeText = "请输入分钟数（如 90 表示 1.5 小时）"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "分钟数"
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            if let minutes = Int(input.stringValue), minutes > 0 {
                selectedTimerMinutes = minutes
                let title = minutes >= 60 ? "\(minutes / 60) 小时 \(minutes % 60) 分钟" : "\(minutes) 分钟"
                timerMenuItem.title = "定时恢复: \(title)"
                startMatcha(mode: .timed)
            }
        }
    }

    @objc private func selectThreshold(_ sender: NSMenuItem) {
        PreferencesManager.shared.batteryThreshold = sender.tag
        if sender.tag == 0 {
            thresholdMenuItem.title = "电量控制: 关闭"
        } else {
            thresholdMenuItem.title = "电量控制: \(sender.tag)%"
        }
    }

    @objc private func customThreshold() {
        let alert = NSAlert()
        alert.messageText = "自定义电量阈值"
        alert.informativeText = "请输入电量百分比（1-100）"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "百分比"
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            if let threshold = Int(input.stringValue), threshold > 0 && threshold <= 100 {
                PreferencesManager.shared.batteryThreshold = threshold
                thresholdMenuItem.title = "电量控制: \(threshold)%"
            }
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let newState = sender.state == .off
        if PreferencesManager.shared.setLaunchAtLogin(newState) {
            sender.state = newState ? .on : .off
        } else {
            sender.state = PreferencesManager.shared.launchAtLogin ? .on : .off
            let alert = NSAlert()
            alert.messageText = "开机自启设置失败"
            alert.informativeText = "请检查系统登录项权限后重试。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }

    @objc private func toggleBatterySleep(_ sender: NSMenuItem) {
        guard beginPowerOperation() else { return }

        let currentlyEnabled = isBatterySleepOverrideActive

        if currentlyEnabled {
            // Disable battery mode
            disableBatterySleepMode { [weak self] success in
                if success {
                    self?.batterySleepMenuItem?.state = .off
                }
                self?.endPowerOperation()
            }
        } else {
            // Enable - need to request admin privileges
            MatchaManager.shared.enableBatterySleep { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        // Start extreme mode with battery enabled
                        self?.clearAllCheckmarks()
                        sender.state = .on
                        MatchaManager.shared.start(mode: .extreme)
                        self?.selectedMode = .extreme
                        self?.endPowerOperation()
                    } else {
                        // Show error alert
                        let alert = NSAlert()
                        alert.messageText = "启用失败"
                        alert.informativeText = error ?? "无法获取管理员权限"
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "确定")
                        alert.runModal()
                        self?.endPowerOperation()
                    }
                }
            }
        }
    }

    @objc private func repairSleepSettings() {
        guard beginPowerOperation() else { return }

        // Stop current caffeinate session first, then force restore battery sleep policy.
        MatchaManager.shared.stop(restoreBatteryOverride: false) { [weak self] in
            MatchaManager.shared.restoreBatterySleep { success, error in
                DispatchQueue.main.async {
                    if success {
                        self?.clearAllCheckmarks()
                        self?.stopMenuItem?.state = .on
                    } else {
                        self?.showBatterySleepRestoreFailedAlert(error)
                    }
                    self?.endPowerOperation()
                }
            }
        }
    }

    private func clearAllCheckmarks() {
        stopMenuItem?.state = .off
        awakeMenuItem?.state = .off
        screenOnMenuItem?.state = .off
        extremeMenuItem?.state = .off
        batterySleepMenuItem?.state = .off
    }

    @objc private func quit() {
        MatchaManager.shared.stop {
            NSApplication.shared.terminate(nil)
        }
    }

    private func startMatcha(mode: MatchaMode) {
        guard beginPowerOperation() else { return }

        if isBatterySleepOverrideActive {
            disableBatterySleepMode { [weak self] success in
                guard success else {
                    self?.endPowerOperation()
                    return
                }
                self?.startMatchaInternal(mode: mode)
                self?.endPowerOperation()
            }
            return
        }

        startMatchaInternal(mode: mode)
        endPowerOperation()
    }

    private func startMatchaInternal(mode: MatchaMode) {
        // Update checkmarks for mode selection
        updateModeCheckmarks(selected: mode)

        // If timer is 0 (permanent), use awake mode instead
        if mode == .timed && selectedTimerMinutes == 0 {
            MatchaManager.shared.start(mode: .awake)
        } else if mode == .timed {
            MatchaManager.shared.start(mode: mode, timerSeconds: selectedTimerMinutes * 60)
        } else {
            MatchaManager.shared.start(mode: mode)
        }
        selectedMode = mode
    }

    private func updateModeCheckmarks(selected: MatchaMode) {
        // Clear all first
        stopMenuItem?.state = .off
        awakeMenuItem?.state = .off
        screenOnMenuItem?.state = .off
        extremeMenuItem?.state = .off
        batterySleepMenuItem?.state = .off

        // Then check the selected mode
        switch selected {
        case .awake:
            awakeMenuItem?.state = .on
        case .screenOn:
            screenOnMenuItem?.state = .on
        case .extreme:
            // Check based on battery mode setting
            if PreferencesManager.shared.batterySleepEnabled {
                batterySleepMenuItem?.state = .on
            } else {
                extremeMenuItem?.state = .on
            }
        case .timed:
            awakeMenuItem?.state = .on
        case .off:
            stopMenuItem?.state = .on
        }
    }

    private var isBatterySleepOverrideActive: Bool {
        PreferencesManager.shared.batterySleepEnabled || PreferencesManager.shared.batterySleepOverrideActive
    }

    private var isBatterySleepModeRunning: Bool {
        PreferencesManager.shared.batterySleepEnabled && MatchaManager.shared.currentMode == .extreme
    }

    private func disableBatterySleepMode(completion: ((Bool) -> Void)? = nil) {
        MatchaManager.shared.restoreBatterySleep { [weak self] success, error in
            if !success {
                self?.showBatterySleepRestoreFailedAlert(error)
            }
            completion?(success)
        }
    }

    private func attemptStartupBatteryRecoveryIfNeeded() {
        guard PreferencesManager.shared.batterySleepOverrideActive else { return }
        guard beginPowerOperation() else { return }

        MatchaManager.shared.recoverBatterySleepIfNeeded { [weak self] success, error in
            if !success {
                self?.showBatterySleepRestoreFailedAlert(error)
            }
            self?.endPowerOperation()
        }
    }

    private func beginPowerOperation() -> Bool {
        guard !isPowerOperationInProgress else { return false }
        isPowerOperationInProgress = true
        updatePowerActionAvailability()
        return true
    }

    private func endPowerOperation() {
        isPowerOperationInProgress = false
        updatePowerActionAvailability()
    }

    private func handleBatterySleepClamshellTransition() {
        guard isBatterySleepModeRunning else {
            lastClamshellClosedState = nil
            return
        }

        guard let isClosed = PowerManager.shared.isClamshellClosed() else {
            return
        }

        let action = BatterySleepDisplayPlanner.action(
            previousIsClosed: lastClamshellClosedState,
            currentIsClosed: isClosed,
            batterySleepEnabled: PreferencesManager.shared.batterySleepEnabled,
            mode: MatchaManager.shared.currentMode
        )

        lastClamshellClosedState = isClosed

        if action == .sleepDisplay {
            MatchaManager.shared.sleepDisplayNow()
        }
    }

    private func updatePowerActionAvailability() {
        let available = !isPowerOperationInProgress
        awakeMenuItem?.isEnabled = available
        screenOnMenuItem?.isEnabled = available
        extremeMenuItem?.isEnabled = available
        batterySleepMenuItem?.isEnabled = available
        repairSleepMenuItem?.isEnabled = available
        timerMenuItem?.isEnabled = available

        stopMenuItem?.isEnabled = available && MatchaManager.shared.isRunning
    }

    private func showBatterySleepRestoreFailedAlert(_ error: String?) {
        let alert = NSAlert()
        alert.messageText = "恢复系统休眠设置失败"
        alert.informativeText = """
        请重试一次，或在终端执行：
        sudo pmset -b disablesleep 0
        详情：\(error ?? "未知错误")
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
