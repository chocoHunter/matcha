# Caffeine

一款 macOS 菜单栏应用，让你的 Mac 保持清醒。

## 功能特点

- **多种防休眠模式**：阻止睡眠、屏幕常亮、合盖不睡、定时模式
- **电池智能恢复**：电量过低时自动恢复休眠（可自定义阈值）
- **手动控制**：一键停止/恢复咖啡因
- **灵活定时**：15分钟到24小时可选，支持永久生效
- **自定义设置**：支持手动输入定时和电量阈值
- **开机自动启动**：登录时自动运行

## 如何构建

### 环境要求
- macOS 13.0+（用于 SMAppService）
- Xcode 15.0+

### 构建步骤

1. 打开 Xcode
2. 创建新项目：`File → New → Project...`
3. 选择 "App"（macOS）
4. 命名为 "Caffeine"，设置 bundle identifier
5. 将 `Sources/` 中的所有 Swift 文件复制到项目源文件夹
6. 在 Info.plist 中设置 `LSUIElement` 为 `true`（隐藏 Dock 图标）
7. 构建：`Product → Build`

### 或使用命令行

```bash
cd Sources
xcrun --sdk macosx swiftc -o Caffeine main.swift AppDelegate.swift StatusBarController.swift CaffeinateManager.swift PowerManager.swift PreferencesManager.swift HistoryManager.swift
```

## 使用方法

1. 点击菜单栏的咖啡杯图标
2. 选择模式以防止休眠：
   - **阻止睡眠**：仅禁止系统睡眠
   - **屏幕常亮**：保持屏幕常亮
   - **合盖不睡**：合盖也能运行（需外接显示器）
   - **定时模式**：设置时长（可选15分钟~24小时，或永久）
3. 运行中可随时点击"恢复"停止
4. 支持自定义定时和电量阈值
5. 开启"开机自启"可实现登录时自动运行

## 项目结构

```
Caffeine/
├── Sources/
│   ├── main.swift              # 应用入口
│   ├── AppDelegate.swift       # 应用代理
│   ├── StatusBarController.swift  # 菜单栏控制器
│   ├── CaffeinateManager.swift # caffeinate 进程管理
│   ├── PowerManager.swift      # 电池状态监控
│   ├── PreferencesManager.swift # 用户偏好设置
│   └── HistoryManager.swift    # 使用历史记录
├── Resources/                  # 资源文件
├── Info.plist                  # 应用配置
└── Caffeine.entitlements       # 权限配置
```

## 技术栈

- Swift 5.9+
- AppKit
- Foundation
- IOKit（电池监控）
- UserDefaults（设置存储）
- ServiceManagement（开机启动）

## 许可证

MIT
