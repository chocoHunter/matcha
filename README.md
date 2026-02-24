# Caffeine

A macOS menu bar app that prevents your Mac from sleeping.

## Features

- **Multiple sleep prevention modes**: Awake, Screen On, Extreme, Timed
- **Battery-aware auto-recovery**: Automatically stop when battery is low
- **Launch at login**: Auto-start when you log in
- **Coffee-themed UI**: Intuitive menu bar interface

## How to Build

### Prerequisites
- macOS 13.0+ (for SMAppService)
- Xcode 15.0+

### Build Steps

1. Open Xcode
2. Create a new project: `File → New → Project...`
3. Select "App" under "macOS"
4. Name it "Caffeine" and set the bundle identifier
5. Copy all Swift files from `Sources/` to your project's source folder
6. Set `LSUIElement` to `true` in Info.plist (to hide from Dock)
7. Build: `Product → Build`

### Or use command line:

```bash
cd Sources
xcrun --sdk macosx swiftc -o Caffeine main.swift AppDelegate.swift StatusBarController.swift CaffeinateManager.swift PowerManager.swift PreferencesManager.swift
```

## Usage

1. Click the coffee cup icon in the menu bar
2. Select a mode to prevent sleep:
   - **清醒模式 (Awake)**: Prevents system sleep
   - **屏幕常亮 (Screen On)**: Keeps display on
   - **极致模式 (Extreme)**: Prevents sleep even with lid closed (requires external display)
   - **定时模式 (Timed)**: Set a duration
3. Configure auto-recovery threshold in settings
4. Enable "开机自动启动" (Launch at Login) if desired

## License

MIT
