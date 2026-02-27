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

        // Mode selection
        let awakeItem = NSMenuItem(title: "阻止睡眠", action: #selector(selectAwake), keyEquivalent: "")
        awakeItem.target = self
        menu.addItem(awakeItem)

        let screenOnItem = NSMenuItem(title: "屏幕常亮", action: #selector(selectScreenOn), keyEquivalent: "")
        screenOnItem.target = self
        menu.addItem(screenOnItem)

        let extremeItem = NSMenuItem(title: "合盖不睡", action: #selector(selectExtreme), keyEquivalent: "")
        extremeItem.target = self
        menu.addItem(extremeItem)

        // Stop button - disabled when not running
        stopMenuItem = NSMenuItem(title: "恢复", action: #selector(stopCaffeinate), keyEquivalent: "")
        stopMenuItem.target = self
        stopMenuItem.isEnabled = false
        menu.addItem(stopMenuItem)

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

            statusMenuItem.title = "状态: \(manager.currentMode.displayName) (\(timeString))"
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
        let info = PowerManager.shared.getBatteryInfo()
        let batteryLevel = level ?? info?.level ?? 0
        let charging = isCharging ?? info?.isCharging ?? false

        let icon = charging ? "🔌" : "🔋"
        batteryMenuItem.title = "电池: \(batteryLevel)% \(icon)"

        // Auto-stop check - only when threshold > 0 (enabled)
        let threshold = PreferencesManager.shared.batteryThreshold
        if threshold > 0 && !charging && batteryLevel <= threshold && MatchaManager.shared.isRunning {
            MatchaManager.shared.stop()
        }
    }

    @objc private func selectAwake() { startCaffeinate(mode: .awake) }
    @objc private func selectScreenOn() { startCaffeinate(mode: .screenOn) }
    @objc private func selectExtreme() { startCaffeinate(mode: .extreme) }
    @objc private func stopCaffeinate() { MatchaManager.shared.stop() }

    @objc private func selectTimer(_ sender: NSMenuItem) {
        selectedTimerMinutes = sender.tag
        if sender.tag == 0 {
            timerMenuItem.title = "定时恢复: 永久"
        } else {
            timerMenuItem.title = "定时恢复: \(sender.title)"
        }
        startCaffeinate(mode: .timed)
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
                startCaffeinate(mode: .timed)
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
        sender.state = newState ? .on : .off
        PreferencesManager.shared.launchAtLogin = newState
    }

    @objc private func quit() {
        MatchaManager.shared.stop()
        NSApplication.shared.terminate(nil)
    }

    private func startCaffeinate(mode: MatchaMode) {
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

    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
