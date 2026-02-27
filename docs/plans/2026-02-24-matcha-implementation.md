# Matcha Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS menu bar app that prevents Mac from sleeping with multiple modes, coffee-themed UI, and battery-aware auto-recovery.

**Architecture:** Pure Swift + AppKit, no external dependencies. Menu bar app using NSStatusItem. Use system caffeinate command for sleep prevention. UserDefaults for preferences. IOKit for battery monitoring.

**Tech Stack:** Swift 5.9+, AppKit, Foundation, IOKit, UserDefaults

---

## Task 1: Create Xcode Project Structure

**Files:**
- Create: `Matcha/Sources/AppDelegate.swift`
- Create: `Matcha/Sources/main.swift`
- Create: `Matcha/Sources/Info.plist`
- Create: `Matcha/Sources/Matcha.entitlements`

**Step 1: Create directory structure**

```bash
mkdir -p Matcha/Sources Matcha/Resources
```

**Step 2: Create main.swift**

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

**Step 3: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIconFile</key>
    <string></string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

**Step 4: Create Matcha.entitlements**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

**Step 5: Commit**

```bash
git add Matcha/Sources/main.swift Matcha/Sources/Info.plist Matcha/Sources/Matcha.entitlements
git commit -m "feat: create Xcode project structure"
```

---

## Task 2: Create AppDelegate with Menu Bar Setup

**Files:**
- Modify: `Matcha/Sources/AppDelegate.swift`

**Step 1: Write basic AppDelegate**

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        CaffeinateManager.shared.stop()
    }
}
```

**Step 2: Create StatusBarController.swift**

```swift
import AppKit

class StatusBarController {
    private var statusItem: NSStatusItem
    private var menu: NSMenu

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        statusItem.menu = menu
        setupMenu()
    }

    private func setupMenu() {
        // Will be implemented in Task 3
    }
}
```

**Step 3: Commit**

```bash
git add Matcha/Sources/AppDelegate.swift
git commit -m "feat: create AppDelegate and StatusBarController skeleton"
```

---

## Task 3: Implement CaffeinateManager

**Files:**
- Create: `Matcha/Sources/CaffeinateManager.swift`

**Step 1: Write CaffeinateManager**

```swift
import Foundation

enum MatchaMode: Int, CaseIterable {
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
    private(set) var currentMode: MatchaMode = .off
    private(set) var startTime: Date?

    var isRunning: Bool {
        return process != nil
    }

    var elapsedTime: TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    func start(mode: MatchaMode, timerSeconds: Int? = nil) {
        stop()

        guard mode != .off else { return }

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
        process?.terminate()
        process = nil
        currentMode = .off
        startTime = nil
        NotificationCenter.default.post(name: .caffeineStateChanged, object: nil)
    }
}

extension Notification.Name {
    static let caffeineStateChanged = Notification.Name("caffeineStateChanged")
}
```

**Step 2: Commit**

```bash
git add Matcha/Sources/CaffeinateManager.swift
git commit -m "feat: implement CaffeinateManager for process control"
```

---

## Task 4: Implement PowerManager for Battery Monitoring

**Files:**
- Create: `Matcha/Sources/PowerManager.swift`

**Step 1: Write PowerManager**

```swift
import Foundation
import IOKit.ps

class PowerManager {
    static let shared = PowerManager()

    private var timer: Timer?
    var onBatteryLevelChanged: ((Int, Bool)) -> Void?
    // (batteryLevel, isCharging)

    private init() {}

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkBattery()
        }
        checkBattery()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first else {
            return
        }

        guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            return
        }

        let currentCapacity = info[kIOPSCurrentCapacityKey as String] as? Int ?? 0
        let isCharging = (info[kIOPSIsChargingKey as String] as? Bool) ?? false

        DispatchQueue.main.async { [weak self] in
            self?.onBatteryLevelChanged?(currentCapacity, isCharging)
        }
    }

    func getBatteryInfo() -> (level: Int, isCharging: Bool)? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            return nil
        }

        let level = info[kIOPSCurrentCapacityKey as String] as? Int ?? 0
        let isCharging = (info[kIOPSIsChargingKey as String] as? Bool) ?? false
        return (level, isCharging)
    }
}
```

**Step 2: Commit**

```bash
git add Matcha/Sources/PowerManager.swift
git commit -m "feat: implement PowerManager for battery monitoring"
```

---

## Task 5: Implement PreferencesManager

**Files:**
- Create: `Matcha/Sources/PreferencesManager.swift`

**Step 1: Write PreferencesManager**

```swift
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
        get { defaults.integer(forKey: Keys.batteryThreshold).nonZero ?? 20 }
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

private extension Int {
    var nonZero: Int? {
        return self == 0 ? nil : self
    }
}
```

**Step 2: Commit**

```bash
git add Matcha/Sources/PreferencesManager.swift
git commit -m "feat: implement PreferencesManager with UserDefaults"
```

---

## Task 6: Build Full StatusBarController with Menu

**Files:**
- Modify: `Matcha/Sources/StatusBarController.swift`

**Step 1: Write complete StatusBarController**

```swift
import AppKit

class StatusBarController: NSObject {
    private var statusItem: NSStatusBar!
    private var menu: NSMenu!
    private var statusMenuItem: NSMenuItem!
    private var batteryMenuItem: NSMenuItem!
    private var timer: Timer?

    private var selectedMode: MatchaMode = .off
    private var selectedTimerMinutes: Int = 15

    override init() {
        super.init()
        setupStatusItem()
        setupMenu()
        startUpdateTimer()
        setupNotifications()
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
        let quitItem = NSMenuItem(title: "退出 Matcha", action: #selector(quit), keyEquivalent: "q")
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
            self?.updateBatteryDisplay(level: level, isCharging: isCharging)
        }

        updateBatteryDisplay()
    }

    @objc private func caffeineStateChanged() {
        updateIcon(for: CaffeinateManager.shared.currentMode)
        updateStatus()
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
        let manager = CaffeinateManager.shared
        if manager.isRunning {
            let elapsed = Int(manager.elapsedTime)
            let hours = elapsed / 3600
            let minutes = (elapsed % 3600) / 60
            let seconds = elapsed % 60
            statusMenuItem.title = "状态: \(manager.currentMode.displayName) (\(String(format: "%02d:%02d:%02d", hours, minutes, seconds)))"
        } else {
            statusMenuItem.title = "状态: 关闭"
        }
    }

    private func updateBatteryDisplay(level: Int? = nil, isCharging: Bool? = nil) {
        let info = PowerManager.shared.getBatteryInfo()
        let batteryLevel = level ?? info?.level ?? 0
        let charging = isCharging ?? info?.isCharging ?? false

        let icon = charging ? "🔌" : "🔋"
        batteryMenuItem.title = "电池: \(batteryLevel)% \(icon)"

        // Auto-stop check
        if !charging && batteryLevel <= PreferencesManager.shared.batteryThreshold && manager.isRunning {
            CaffeinateManager.shared.stop()
        }
    }

    @objc private func selectAwake() { startCaffeinate(mode: .awake) }
    @objc private func selectScreenOn() { startCaffeinate(mode: .screenOn) }
    @objc private func selectExtreme() { startCaffeinate(mode: .extreme) }

    @objc private func selectTimer(_ sender: NSMenuItem) {
        selectedTimerMinutes = sender.tag
        sender.menu?.items.forEach { $0.state = .off }
        sender.state = .on
    }

    @objc private func selectThreshold(_ sender: NSMenuItem) {
        PreferencesManager.shared.batteryThreshold = sender.tag
        sender.menu?.items.forEach { $0.state = .off }
        sender.state = .on
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

    private func startCaffeinate(mode: MatchaMode) {
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
```

**Step 2: Commit**

```bash
git add Matcha/Sources/StatusBarController.swift
git commit -m "feat: implement full StatusBarController with menu"
```

---

## Task 7: Add Launch at Login Support

**Files:**
- Modify: `Matcha/Sources/PreferencesManager.swift`

**Step 1: Add login item helper**

```swift
import Foundation
import ServiceManagement

extension PreferencesManager {
    func updateLaunchAtLogin() {
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
```

**Step 2: Modify toggle in StatusBarController**

Update the `toggleLaunchAtLogin` method to call `PreferencesManager.shared.updateLaunchAtLogin()` after toggling.

**Step 3: Commit**

```bash
git add Matcha/Sources/StatusBarController.swift Matcha/Sources/PreferencesManager.swift
git commit -m "feat: add launch at login support"
```

---

## Task 8: Test Build

**Step 1: Create Xcode project**

```bash
cd Matcha
swift package init --type executable
# Then configure in Xcode to use AppKit and create .app bundle
```

Or use Xcode GUI to create new project and add Swift files.

**Step 2: Build and test**

```bash
# In Xcode: Product > Build
# Or command line if configured
```

**Step 3: Verify**

- Menu bar icon appears
- Click shows menu
- Mode selection works
- Timer works
- Battery display updates

**Step 4: Commit**

```bash
git add .
git commit -m "feat: complete Matcha app implementation"
```

---

## Task 9: Create Release Configuration

**Files:**
- Create: `Matcha/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`

**Step 1: Add app icon**

Create simple coffee cup icon or use SF Symbols in code.

**Step 2: Configure release build**

Update Info.plist with proper bundle settings.

**Step 3: Commit**

```bash
git add Matcha/Resources/
git commit -m "feat: add app icon and release config"
```

---

## Plan Complete

**Plan saved to:** `docs/plans/2026-02-24-caffeine-implementation.md`

Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
