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
    private var awakeMenuItem: NSMenuItem!
    private var screenOnMenuItem: NSMenuItem!
    private var extremeMenuItem: NSMenuItem!
    private var timer: Timer?

    private var selectedMode: MatchaMode = .off
    private var selectedTimerMinutes: Int = 0 // 0 means permanent

    override init() {
        super.init()
        setupStatusItem()
        setupMenu()
        startUpdateTimer()
        setupNotifications()
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
    }

    private func startUpdateTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(matchaStateChanged),
            name: .matchaStateChanged,
            object: nil
        )

        PowerManager.shared.startMonitoring()
        PowerManager.shared.onBatteryLevelChanged = { [weak self] level, isCharging in
            guard let self = self else { return }
            self.updateBatteryDisplay(level: level, isCharging: isCharging)
        }

        updateBatteryDisplay()
    }

    @objc private func matchaStateChanged() {
        updateIcon(for: MatchaManager.shared.currentMode)
        updateStatus()
        updateModeCheckmarks(selected: MatchaManager.shared.currentMode)
        // Enable/disable stop button based on running state
        stopMenuItem.isEnabled = MatchaManager.shared.isRunning
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
        if threshold > 0 && !charging && batteryLevel <= threshold && MatchaManager.shared.isRunning {
            MatchaManager.shared.stop()
        }
    }

    @objc private func selectAwake() {
        // Disable battery mode if enabled
        if PreferencesManager.shared.batterySleepEnabled {
            disableBatterySleepMode()
        }
        startMatcha(mode: .awake)
    }

    @objc private func selectScreenOn() {
        // Disable battery mode if enabled
        if PreferencesManager.shared.batterySleepEnabled {
            disableBatterySleepMode()
        }
        startMatcha(mode: .screenOn)
    }

    @objc private func selectExtreme() {
        // Disable battery mode for AC power mode
        if PreferencesManager.shared.batterySleepEnabled {
            disableBatterySleepMode()
        }
        // Clear all and check extreme
        clearAllCheckmarks()
        extremeMenuItem?.state = .on
        MatchaManager.shared.start(mode: .extreme)
        selectedMode = .extreme
    }
    @objc private func stopMatcha() {
        if PreferencesManager.shared.batterySleepEnabled {
            disableBatterySleepMode()
        }
        MatchaManager.shared.stop()
        // Clear all checkmarks and check "恢复休眠"
        stopMenuItem?.state = .on
        awakeMenuItem?.state = .off
        screenOnMenuItem?.state = .off
        extremeMenuItem?.state = .off
        batterySleepMenuItem?.state = .off
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
        let currentlyEnabled = PreferencesManager.shared.batterySleepEnabled

        if currentlyEnabled {
            // Disable battery mode
            disableBatterySleepMode()
            sender.state = .off
        } else {
            // Enable - need to request admin privileges
            MatchaManager.shared.enableBatterySleep { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        PreferencesManager.shared.batterySleepEnabled = true
                        // Start extreme mode with battery enabled
                        self?.clearAllCheckmarks()
                        sender.state = .on
                        MatchaManager.shared.start(mode: .extreme)
                        self?.selectedMode = .extreme
                    } else {
                        // Show error alert
                        let alert = NSAlert()
                        alert.messageText = "启用失败"
                        alert.informativeText = error ?? "无法获取管理员权限"
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "确定")
                        alert.runModal()
                    }
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
        if PreferencesManager.shared.batterySleepEnabled {
            disableBatterySleepMode()
        }
        MatchaManager.shared.stop()
        NSApplication.shared.terminate(nil)
    }

    private func startMatcha(mode: MatchaMode) {
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

    private func disableBatterySleepMode() {
        PreferencesManager.shared.batterySleepEnabled = false
        MatchaManager.shared.restoreBatterySleep()
    }

    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
