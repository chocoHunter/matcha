# Matcha

A macOS menu bar app that prevents your Mac from sleeping.

## Features

- **Multiple sleep prevention modes**: Prevent Sleep, Screen On, Lid Closed (AC/Battery), Timed
- **Lid Closed on Battery**: Allow lid closed mode without power adapter and sleep the display after the lid closes (requires authorization)
- **Battery-aware auto-recovery**: Automatically stop when battery is low (customizable)
- **Manual control**: Stop/Resume sleep prevention with one click
- **Flexible timers**: 15 min to 24 hours, or permanent
- **Custom settings**: Manual input for timer and battery threshold
- **Launch at login**: Auto-start when you log in

## Safety Notes

- The **Lid Closed (Battery)** mode changes system power settings via `pmset` (admin authorization required).
- Matcha restores these settings automatically when you stop the mode, switch modes, timer ends, or quit.
- Matcha also snapshots your current battery sleep settings before enabling battery mode and restores them on exit paths or startup recovery.
- In battery mode, Matcha watches for lid-close transitions and asks macOS to sleep the display after the lid closes. This usually happens within about 1 second.
- If anything goes wrong, use menu item **Repair Sleep Settings** first.
- You can also recover manually:

```bash
sudo pmset -b disablesleep 0
sudo pmset restoredefaults
```

## How to Build

### Prerequisites

- macOS 13.0+ (for SMAppService)
- Xcode 15.0+
- XcodeGen (install via `brew install xcodegen`)
- appdmg (install via `npm install -g appdmg`)
- Ensure full Xcode is selected (`xcode-select -p` should point to `/Applications/Xcode.app/...`, not CommandLineTools only)

### Complete Build Process

#### 0. One-command release build

```bash
./scripts/build-release-artifacts.sh
```

This builds the Release `.app`, verifies it with `codesign`, creates `Build/Matcha.dmg`, mounts the image, and confirms that `Matcha.app` is present inside.

#### 1. Generate Xcode Project

```bash
xcodegen generate
```

This creates `Matcha.xcodeproj` from `project.yml`.

#### 2. Build App

```bash
# Using Xcode command line
"/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild" -project Matcha.xcodeproj -scheme Matcha -configuration Release build

# Or open Matcha.xcodeproj in Xcode and build via Product → Build
```

Build output: `~/Library/Developer/Xcode/DerivedData/Matcha-*/Build/Products/Release/Matcha.app`

#### 3. Create DMG Installer

```bash
# Get the built App path
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Matcha.app" -type d -path "*/Release/*.app" | head -1)

# Create DMG config
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

# Replace path
sed -i '' "s|\$APP_PATH|$APP_PATH|g" /tmp/appdmg.json

# Create DMG
appdmg /tmp/appdmg.json Matcha.dmg
```

### Alternative: Command Line Only (no Xcode)

```bash
cd Sources
xcrun --sdk macosx swiftc -o Matcha main.swift AppDelegate.swift StatusBarController.swift MatchaManager.swift PowerManager.swift PreferencesManager.swift HistoryManager.swift BatterySleepSupport.swift
```

Note: Command line build does not include Resources (icons need to be handled separately).

## Tests

```bash
xcodegen generate
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project Matcha.xcodeproj -scheme MatchaTests -sdk macosx test -destination 'platform=macOS'
```

Release artifact verification:

```bash
./scripts/build-release-artifacts.sh
```

## Usage

1. Click the coffee cup icon in the menu bar
2. Select a mode (modes are mutually exclusive, only one will be checked):
   - **Resume Sleep**: Default state, stops all sleep prevention
   - **Prevent Sleep**: Prevents system sleep
   - **Screen On**: Keeps display on
   - **Lid Closed (AC)**: Prevents sleep even with lid closed (requires external display and power)
   - **Lid Closed (Battery)**: Prevents sleep even with lid closed on battery, then sleeps the display after the lid closes (requires admin authorization on first enable)
   - **Timed**: Set a duration (15 min to 24 hours, or permanent)
3. Click "Resume Sleep" to stop at any time
4. Custom timer and battery threshold input supported
5. Enable "Launch at Login" if desired
6. If sleep behavior looks abnormal, click **Repair Sleep Settings**

### Battery Mode Behavior

- Battery mode is designed to keep the Mac running while the lid is closed, without keeping the built-in display visibly on.
- The display sleep trigger happens after Matcha detects the lid-close transition, so a short delay of about 1 second is expected.
- When you open the lid again, display wake is left to normal macOS behavior.

## Troubleshooting

### Lid-close does not sleep after using battery mode

1. Click **Repair Sleep Settings** in Matcha menu
2. If it still fails, run:

```bash
sudo pmset -b disablesleep 0
sudo pmset restoredefaults
```

3. Re-test by closing the lid with external displays unplugged

### Battery mode keeps running but the display does not turn off

1. Make sure you are using the latest build of Matcha.
2. Wait about 1 second after closing the lid; the display sleep is triggered after the close transition is detected.
3. Re-test with external displays, docks, or HDMI adapters unplugged.
4. If needed, quit and relaunch Matcha, then enable **Lid Closed (Battery)** again.

## License

MIT
