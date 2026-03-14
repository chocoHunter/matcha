# Matcha

一款 macOS 菜单栏应用，让你的 Mac 保持清醒。

## 功能特点

- **多种防休眠模式**：阻止睡眠、屏幕常亮、合盖不睡（插电/电池）、定时模式
- **合盖不睡（电池）**：支持不插电合盖不睡，并在合盖后关闭显示屏（需管理员授权）
- **电池智能恢复**：电量过低时自动恢复休眠（可自定义阈值）
- **手动控制**：一键停止/恢复休眠
- **灵活定时**：15分钟到24小时可选，支持永久生效
- **自定义设置**：支持手动输入定时和电量阈值
- **开机自动启动**：登录时自动运行

## 安全说明

- **合盖不睡（电池）** 会通过 `pmset` 修改系统电源策略（需要管理员授权）。
- Matcha 会在停止该模式、切换模式、定时结束、退出应用时自动恢复系统设置。
- Matcha 会在启用电池模式前快照当前电池电源设置，并在退出路径或启动自愈时恢复。
- 在电池模式下，Matcha 会监听合盖状态变化，并在检测到“开盖 -> 合盖”后请求系统关闭显示屏，通常会有约 1 秒内的延迟。
- 若出现异常，请先使用菜单中的 **修复休眠设置**。
- 也可手动恢复：

```bash
sudo pmset -b disablesleep 0
sudo pmset restoredefaults
```

## 如何构建

### 环境要求

- macOS 13.0+（用于 SMAppService）
- Xcode 15.0+
- XcodeGen（安装：`brew install xcodegen`）
- appdmg（安装：`npm install -g appdmg`）
- 请确认已选择完整 Xcode（`xcode-select -p` 应指向 `/Applications/Xcode.app/...`，而不是仅 CommandLineTools）

### 完整构建流程

#### 0. 一键构建发布产物

```bash
./scripts/build-release-artifacts.sh
```

这条命令会构建 Release `.app`、执行 `codesign` 校验、生成 `Build/Matcha.dmg`、挂载镜像，并确认其中包含 `Matcha.app`。

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

也可以直接运行：

```bash
./scripts/build-release-artifacts.sh
```

### 或使用命令行（无需 Xcode）

```bash
cd Sources
xcrun --sdk macosx swiftc -o Matcha main.swift AppDelegate.swift StatusBarController.swift MatchaManager.swift PowerManager.swift PreferencesManager.swift HistoryManager.swift BatterySleepSupport.swift
```

注意：命令行方式构建不包含 Resources（图标准备工作需单独处理）。

## 测试

```bash
xcodegen generate
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project Matcha.xcodeproj -scheme MatchaTests -sdk macosx test -destination 'platform=macOS'
```

发布产物验证：

```bash
./scripts/build-release-artifacts.sh
```

## 使用方法

1. 点击菜单栏的咖啡杯图标
2. 选择模式（各模式互斥，点击后只会有一个打钩）：
   - **恢复休眠**：默认状态，停止所有防休眠功能
   - **阻止睡眠**：仅禁止系统睡眠
   - **屏幕常亮**：保持屏幕常亮
   - **合盖不睡（插电）**：合盖也能运行（需外接显示器，插电源）
   - **合盖不睡（电池）**：合盖也能运行（不插电，首次开启需管理员授权），并在合盖后关闭显示屏
   - **定时模式**：设置时长（可选15分钟~24小时，或永久）
3. 运行中可随时点击"恢复休眠"停止
4. 支持自定义定时和电量阈值
5. 开启"开机自启"可实现登录时自动运行
6. 若休眠行为异常，可点击 **修复休眠设置**

### 电池模式行为说明

- 电池模式的目标是让 Mac 在合盖后继续运行，同时不让内建屏幕一直亮着。
- 由于显示屏关闭是在检测到合盖状态变化后触发的，所以通常会有约 1 秒的响应时间。
- 再次打开盖子后，显示屏恢复亮起依赖 macOS 的默认行为。

## 故障排查

### 使用电池模式后合盖不休眠

1. 在 Matcha 菜单点击 **修复休眠设置**
2. 如果仍异常，执行：

```bash
sudo pmset -b disablesleep 0
sudo pmset restoredefaults
```

3. 拔掉外接显示器后再次合盖测试

### 电池模式仍在运行，但合盖后屏幕没有熄灭

1. 请确认你运行的是最新构建版本。
2. 合盖后等待约 1 秒再观察，显示屏关闭是在检测到合盖状态变化后触发的。
3. 拔掉外接显示器、扩展坞或 HDMI 转接器后重新测试。
4. 如仍异常，可退出并重新打开 Matcha，再重新启用 **合盖不睡（电池）**。

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
