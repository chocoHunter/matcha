# Matcha

一款 macOS 菜单栏应用，让你的 Mac 保持清醒。

## 功能特点

- **多种防休眠模式**：阻止睡眠、屏幕常亮、合盖不睡（插电/电池）、定时模式
- **合盖不睡（电池）**：支持不插电合盖不睡（需管理员授权）
- **电池智能恢复**：电量过低时自动恢复休眠（可自定义阈值）
- **手动控制**：一键停止/恢复休眠
- **灵活定时**：15分钟到24小时可选，支持永久生效
- **自定义设置**：支持手动输入定时和电量阈值
- **开机自动启动**：登录时自动运行

## 如何构建

### 环境要求

- macOS 13.0+（用于 SMAppService）
- Xcode 15.0+
- XcodeGen（安装：`brew install xcodegen`）
- appdmg（安装：`npm install -g appdmg`）

### 完整构建流程

#### 1. 生成 Xcode 项目

```bash
xcodegen generate
```

这会从 `project.yml` 生成 `Matcha.xcodeproj`。

#### 2. 构建 App

```bash
# 方式一：使用 Xcode 命令行
"/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild" -project Matcha.xcodeproj -scheme Matcha -configuration Release build

# 方式二：直接双击打开 Matcha.xcodeproj，在 Xcode 中按 Cmd + B
```

构建产物位于：`~/Library/Developer/Xcode/DerivedData/Matcha-*/Build/Products/Release/Matcha.app`

#### 3. 创建 DMG 安装包

```bash
# 获取构建后的 App 路径
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Matcha.app" -type d -path "*/Release/*.app" | head -1)

# 创建 DMG 配置
cat > /tmp/appdmg.json << 'EOF'
{
  "title": "Matcha",
  "window": {
    "size": { "width": 450, "height": 300 }
  },
  "contents": [
    { "type": "file", "path": "$APP_PATH", "name": "Matcha.app", "x": 100, "y": 80 },
    { "type": "link", "path": "/Applications", "name": "Applications", "x": 300, "y": 80 }
  ],
  "icon-size": 90
}
EOF

# 替换路径
sed -i '' "s|\$APP_PATH|$APP_PATH|g" /tmp/appdmg.json

# 创建 DMG
appdmg /tmp/appdmg.json Matcha.dmg
```

### 快速构建脚本

也可以直接运行项目中的构建脚本（如果存在）。

### 或使用命令行（无需 Xcode）

```bash
cd Sources
xcrun --sdk macosx swiftc -o Matcha main.swift AppDelegate.swift StatusBarController.swift MatchaManager.swift PowerManager.swift PreferencesManager.swift HistoryManager.swift
```

注意：命令行方式构建不包含 Resources（图标准备工作需单独处理）。

## 使用方法

1. 点击菜单栏的咖啡杯图标
2. 选择模式（各模式互斥，点击后只会有一个打钩）：
   - **恢复休眠**：默认状态，停止所有防休眠功能
   - **阻止睡眠**：仅禁止系统睡眠
   - **屏幕常亮**：保持屏幕常亮
   - **合盖不睡（插电）**：合盖也能运行（需外接显示器，插电源）
   - **合盖不睡（电池）**：合盖也能运行（不插电，首次开启需管理员授权）
   - **定时模式**：设置时长（可选15分钟~24小时，或永久）
3. 运行中可随时点击"恢复休眠"停止
4. 支持自定义定时和电量阈值
5. 开启"开机自启"可实现登录时自动运行

## 项目结构

```
Matcha/
├── Sources/
│   ├── main.swift              # 应用入口
│   ├── AppDelegate.swift       # 应用代理
│   ├── StatusBarController.swift  # 菜单栏控制器
│   ├── MatchaManager.swift # matcha 进程管理
│   ├── PowerManager.swift      # 电池状态监控
│   ├── PreferencesManager.swift # 用户偏好设置
│   └── HistoryManager.swift    # 使用历史记录
├── Resources/                  # 资源文件
├── Info.plist                  # 应用配置
└── Matcha.entitlements       # 权限配置
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
