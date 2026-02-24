# Caffeine

A macOS menu bar app that prevents your Mac from sleeping.

## Features

- **Multiple sleep prevention modes**: Prevent Sleep, Screen On, Lid Closed, Timed
- **Battery-aware auto-recovery**: Automatically stop when battery is low (customizable)
- **Manual control**: Stop/Resume caffeinate with one click
- **Flexible timers**: 15 min to 24 hours, or permanent
- **Custom settings**: Manual input for timer and battery threshold
- **Launch at login**: Auto-start when you log in

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
   - **Prevent Sleep**: Prevents system sleep
   - **Screen On**: Keeps display on
   - **Lid Closed**: Prevents sleep even with lid closed (requires external display)
   - **Timed**: Set a duration (15 min to 24 hours, or permanent)
3. Click "Resume" to stop at any time
4. Custom timer and battery threshold input supported
5. Enable "Launch at Login" if desired

## License

MIT
