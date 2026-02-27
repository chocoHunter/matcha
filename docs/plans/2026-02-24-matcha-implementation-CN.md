# Matcha 实现计划

> **目标：** 构建一个 macOS 菜单栏应用，通过多种模式防止 Mac 休眠，具有咖啡因主题 UI 和电池感知自动恢复功能。

**架构：** 纯 Swift + AppKit，无外部依赖。使用 NSStatusItem 实现菜单栏应用。使用系统 caffeinate 命令防止休眠。使用 UserDefaults 存储偏好设置。使用 IOKit 监控电池状态。

**技术栈：** Swift 5.9+、AppKit、Foundation、IOKit、UserDefaults

---

## 任务 1: 创建 Xcode 项目结构

**文件：**
- 创建：`Matcha/Sources/AppDelegate.swift`
- 创建：`Matcha/Sources/main.swift`
- 创建：`Matcha/Sources/Info.plist`
- 创建：`Matcha/Sources/Matcha.entitlements`

### 步骤 1: 创建目录结构

```bash
mkdir -p Matcha/Sources Matcha/Resources
```

### 步骤 2: 创建 main.swift

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

### 步骤 3: 创建 Info.plist

配置应用基本信息，设置 `LSUIElement` 为 `true` 使应用不显示在 Dock 中。

### 步骤 4: 创建 entitlements 文件

配置应用权限。

### 步骤 5: 提交

```bash
git add Matcha/Sources/main.swift Matcha/Sources/Info.plist Matcha/Sources/Matcha.entitlements
git commit -m "feat: create Xcode project structure"
```

---

## 任务 2: 创建 AppDelegate 和菜单栏基础

**文件：**
- 修改：`Matcha/Sources/AppDelegate.swift`

### 步骤 1: 编写 AppDelegate

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

### 步骤 2: 创建 StatusBarController 框架

创建菜单栏控制器的基础框架。

### 步骤 3: 提交

---

## 任务 3: 实现 CaffeinateManager

**文件：**
- 创建：`Matcha/Sources/CaffeinateManager.swift`

### 核心功能

- 管理 caffeinate 进程
- 支持多种模式：off、awake、screenOn、extreme、timed
- 记录开始时间和运行状态

### 模式说明

| 模式 | 说明 | 命令 |
|------|------|------|
| off | 关闭 | - |
| awake | 仅禁止睡眠 | caffeinate -i |
| screenOn | 屏幕常亮 | caffeinate -d |
| extreme | 合盖运行 | caffeinate -i -s |
| timed | 定时模式 | caffeinate -i -t <秒> |

### 提交

```bash
git add Matcha/Sources/CaffeinateManager.swift
git commit -m "feat: implement CaffeinateManager for process control"
```

---

## 任务 4: 实现 PowerManager 电池监控

**文件：**
- 创建：`Matcha/Sources/PowerManager.swift`

### 核心功能

- 使用 IOKit 读取电池信息
- 定时检查电池电量和充电状态
- 回调通知电池变化

### 提交

```bash
git add Matcha/Sources/PowerManager.swift
git commit -m "feat: implement PowerManager for battery monitoring"
```

---

## 任务 5: 实现 PreferencesManager 偏好设置

**文件：**
- 创建：`Matcha/Sources/PreferencesManager.swift`

### 存储的设置

- batteryThreshold：电池自动恢复阈值
- launchAtLogin：开机自动启动
- lastMode：上次使用的模式

### 提交

```bash
git add Matcha/Sources/PreferencesManager.swift
git commit -m "feat: implement PreferencesManager with UserDefaults"
```

---

## 任务 6: 构建完整的 StatusBarController

**文件：**
- 修改：`Matcha/Sources/StatusBarController.swift`

### 菜单结构

```
状态: 关闭
电池: 85% 🔌
今日累计: 15 分钟
─────────────────────
清醒模式
屏幕常亮
极致模式
─────────────────────
定时: 15 分钟
─────────────────────
电池低于 20% 自动恢复
开机自动启动
─────────────────────
退出 Matcha
```

### 核心功能

- 状态显示（当前模式、运行时间、剩余时间）
- 电池监控显示
- 今日累计使用时长
- 模式选择
- 定时设置
- 阈值设置
- 开机启动开关

### 提交

```bash
git add Matcha/Sources/StatusBarController.swift
git commit -m "feat: implement full StatusBarController with menu"
```

---

## 任务 7: 添加开机启动支持

**文件：**
- 修改：`Matcha/Sources/PreferencesManager.swift`

### 实现

使用 macOS 13.0+ 的 SMAppService 实现开机启动。

### 提交

```bash
git add Matcha/Sources/StatusBarController.swift Matcha/Sources/PreferencesManager.swift
git commit -m "feat: add launch at login support"
```

---

## 任务 8: 添加使用历史记录

**文件：**
- 创建：`Matcha/Sources/HistoryManager.swift`

### 功能

- 记录今日累计使用时长
- 自动跨天重置

### 提交

```bash
git add Matcha/Sources/HistoryManager.swift
git commit -m "feat: add history tracking for today's usage"
```

---

## 任务 9: 测试构建

### 步骤 1: 构建项目

使用 Xcode 构建或命令行编译。

### 步骤 2: 验证

- 菜单栏图标显示
- 点击显示菜单
- 模式选择正常
- 定时功能正常
- 电池显示更新

### 步骤 3: 提交

---

## 任务 10: 创建发布配置

**文件：**
- 创建：`Matcha/Resources/Assets.xcassets/`

### 步骤 1: 添加应用图标

使用 SF Symbols 或创建自定义图标。

### 步骤 2: 配置发布构建

更新 Info.plist 中的 bundle 设置。

### 步骤 3: 提交

---

## 计划完成

**计划保存位置：** `docs/plans/2026-02-24-caffeine-implementation.md`

---

## 下一步

1. 在 Xcode 中打开项目进行完整测试
2. 准备发布版本（.dmg 安装包）
3. 可选：上架 App Store（需要 Apple Developer 账号）
