# Matcha

A macOS menu bar app that prevents your Mac from sleeping.

## Features

- **Multiple sleep prevention modes**: Prevent Sleep, Screen On, Lid Closed (AC/Battery), Timed
- **Lid Closed on Battery**: Allow lid closed mode without power adapter (requires authorization)
- **Battery-aware auto-recovery**: Automatically stop when battery is low (customizable)
- **Manual control**: Stop/Resume sleep prevention with one click
- **Flexible timers**: 15 min to 24 hours, or permanent
- **Custom settings**: Manual input for timer and battery threshold
- **Launch at login**: Auto-start when you log in

## How to Build

### Prerequisites

- macOS 13.0+ (for SMAppService)
- Xcode 15.0+
- XcodeGen (install via `brew install xcodegen`)
- appdmg (install via `npm install -g appdmg`)

### Complete Build Process

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
xcrun --sdk macosx swiftc -o Matcha main.swift AppDelegate.swift StatusBarController.swift MatchaManager.swift PowerManager.swift PreferencesManager.swift
```

Note: Command line build does not include Resources (icons need to be handled separately).

## Usage

1. Click the coffee cup icon in the menu bar
2. Select a mode (modes are mutually exclusive, only one will be checked):
   - **Resume Sleep**: Default state, stops all sleep prevention
   - **Prevent Sleep**: Prevents system sleep
   - **Screen On**: Keeps display on
   - **Lid Closed (AC)**: Prevents sleep even with lid closed (requires external display and power)
   - **Lid Closed (Battery)**: Prevents sleep even with lid closed on battery (requires admin authorization on first enable)
   - **Timed**: Set a duration (15 min to 24 hours, or permanent)
3. Click "Resume Sleep" to stop at any time
4. Custom timer and battery threshold input supported
5. Enable "Launch at Login" if desired

## License

MIT
