import AppKit

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var statusMenuItem: NSMenuItem!
    private var batteryMenuItem: NSMenuItem!
    private var historyMenuItem: NSMenuItem!
    private var timer: Timer?

    private var selectedMode: CaffeineMode = .off
    private var selectedTimerMinutes: Int = 15

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
        if let button = statusItem.button {
            updateIcon(for: .off)
        }
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
        let awakeItem = NSMenuItem(title: "清醒模式", action: #selector(selectAwake), keyEquivalent: "")
        awakeItem.target = self
        menu.addItem(awakeItem)

        let screenOnItem = NSMenuItem(title: "屏幕常亮", action: #selector(selectScreenOn), keyEquivalent: "")
        screenOnItem.target = self
        menu.addItem(screenOnItem)

        let extremeItem = NSMenuItem(title: "极致模式", action: #selector(selectExtreme), keyEquivalent: "")
        extremeItem.target = self
        menu.addItem(extremeItem)

        menu.addItem(NSMenuItem.separator())

        // Timer submenu
        let timerMenu = NSMenu()
        for minutes in [5, 15, 30, 60, 120] {
            let item = NSMenuItem(title: "\(minutes) 分钟", action: #selector(selectTimer(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            timerMenu.addItem(item)
        }
        let timerItem = NSMenuItem(title: "定时: 15 分钟", action: nil, keyEquivalent: "")
        timerItem.submenu = timerMenu
        menu.addItem(timerItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let thresholdMenu = NSMenu()
        for threshold in [10, 20, 30, 50] {
            let item = NSMenuItem(title: "\(threshold)%", action: #selector(selectThreshold(_:)), keyEquivalent: "")
            item.target = self
            item.tag = threshold
            thresholdMenu.addItem(item)
        }
        let thresholdItem = NSMenuItem(title: "电池低于 20% 自动恢复", action: nil, keyEquivalent: "")
        thresholdItem.submenu = thresholdMenu
        menu.addItem(thresholdItem)

        let launchItem = NSMenuItem(title: "开机自动启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = PreferencesManager.shared.launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "退出 Caffeine", action: #selector(quit), keyEquivalent: "q")
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
            selector: #selector(caffeineStateChanged),
            name: .caffeineStateChanged,
            object: nil
        )

        PowerManager.shared.startMonitoring()
        PowerManager.shared.onBatteryLevelChanged = { [weak self] level, isCharging in
            guard let self = self else { return }
            self.updateBatteryDisplay(level: level, isCharging: isCharging)
        }

        updateBatteryDisplay()
    }

    @objc private func caffeineStateChanged() {
        updateIcon(for: CaffeinateManager.shared.currentMode)
        updateStatus()
    }

    private func updateIcon(for mode: CaffeineMode) {
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

        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Caffeine")
    }

    private func updateStatus() {
        let manager = CaffeinateManager.shared
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

        // Auto-stop check
        if !charging && batteryLevel <= PreferencesManager.shared.batteryThreshold && CaffeinateManager.shared.isRunning {
            CaffeinateManager.shared.stop()
        }
    }

    @objc private func selectAwake() { startCaffeinate(mode: .awake) }
    @objc private func selectScreenOn() { startCaffeinate(mode: .screenOn) }
    @objc private func selectExtreme() { startCaffeinate(mode: .extreme) }

    @objc private func selectTimer(_ sender: NSMenuItem) {
        selectedTimerMinutes = sender.tag
        if let timerItem = menu.item(withTitle: "定时: 15 分钟") {
            timerItem.title = "定时: \(sender.tag) 分钟"
        }
    }

    @objc private func selectThreshold(_ sender: NSMenuItem) {
        PreferencesManager.shared.batteryThreshold = sender.tag
        if let thresholdItem = menu.items.first(where: { $0.title.hasPrefix("电池低于") }) {
            thresholdItem.title = "电池低于 \(sender.tag)% 自动恢复"
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let newState = sender.state == .off
        sender.state = newState ? .on : .off
        PreferencesManager.shared.launchAtLogin = newState
    }

    @objc private func quit() {
        CaffeinateManager.shared.stop()
        NSApplication.shared.terminate(nil)
    }

    private func startCaffeinate(mode: CaffeineMode) {
        if mode == .timed {
            CaffeinateManager.shared.start(mode: mode, timerSeconds: selectedTimerMinutes * 60)
        } else {
            CaffeinateManager.shared.start(mode: mode)
        }
        selectedMode = mode
    }

    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
