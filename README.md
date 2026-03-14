# Matcha

A macOS menu bar app for preventing sleep, with practical lid-closed modes for MacBook users.

## Features

- Multiple sleep prevention modes: Prevent Sleep, Screen On, Lid Closed (AC/Battery), Timed
- Lid Closed (Battery): keep running on battery and sleep built-in display after lid close (admin auth required)
- Battery-aware auto-recovery with custom threshold
- One-click stop/resume
- Flexible timer (15 min to 24 hours, or permanent)
- Launch at login

## Install

### Option 1: Download release (recommended)

1. Open [Releases](https://github.com/chocoHunter/matcha/releases).
2. Download the latest `Matcha.dmg`.
3. Drag `Matcha.app` into `/Applications`.
4. Launch Matcha and grant permissions when prompted.

### Option 2: Build from source

Use the build steps in `How to Build` below.

## Usage

1. Click the Matcha menu bar icon.
2. Select one mode (modes are mutually exclusive).
3. Use **Resume Sleep** to return to normal anytime.
4. If behavior looks abnormal, click **Repair Sleep Settings** first.

![Lid Closed AC](docs/assets/screenshots/mode-lid-ac.png)

## Mode Differences

| Mode | What it mainly does | Screen allowed to sleep? | System allowed to idle sleep? | Best for |
| --- | --- | --- | --- | --- |
| **Prevent Sleep** | Prevents idle system sleep | Yes | No | Downloads, scripts, long-running background work |
| **Screen On** | Prevents the display from sleeping | No | Possibly, depending on other system conditions | Presentations, dashboards, keeping the screen visible |
| **Lid Closed (AC)** | Keeps the Mac awake with the lid closed while on AC power | Built-in display can sleep after lid close | No | Closed-lid tasks while charging |
| **Lid Closed (Battery)** | Keeps the Mac awake on battery and then sleeps the built-in display after the lid closes | Built-in display is asked to sleep after lid-close | No | Closed-lid battery use with lower heat and lower display power draw |
| **Timed** | Prevents idle sleep for a chosen duration | Yes | No, until the timer ends | Temporary tasks that should stop automatically |

Practical rule of thumb:

- Choose **Prevent Sleep** if you want the Mac to keep working but you do not care whether the screen stays on.
- Choose **Screen On** if your main goal is to keep the display visible.
- Choose **Timed** when you want sleep prevention for a limited period only.
- Choose **Lid Closed (Battery)** when you want closed-lid operation without the built-in display staying visibly on.

## Battery Mode Behavior

- Battery mode is designed to keep the Mac running while the lid is closed, without keeping the built-in display visibly on.
- Display sleep is triggered after Matcha detects the lid-close transition, so about a 1-second delay is expected.
- When the lid is opened again, display wake follows normal macOS behavior.

## Troubleshooting

### Lid-close does not recover after using battery mode

1. Click **Repair Sleep Settings** in Matcha.
2. If it still fails, run:

```bash
sudo pmset -b disablesleep 0
sudo pmset restoredefaults
```

3. Re-test after disconnecting docks/adapters.

### Battery mode runs but display does not turn off after lid close

1. Confirm you are on the latest build.
2. Wait about 1 second after lid close.
3. Re-test after disconnecting docks or HDMI adapters.
4. Quit and relaunch Matcha, then enable **Lid Closed (Battery)** again.

## Safety Notes

- **Lid Closed (Battery)** changes system battery power settings via `pmset` (admin authorization required).
- Matcha snapshots your prior battery sleep settings before enabling battery mode.
- Settings are restored when you stop mode, switch mode, timer ends, app quits, or startup recovery runs.

Manual emergency restore:

```bash
sudo pmset -b disablesleep 0
sudo pmset restoredefaults
```

## Project Docs

- `CONTRIBUTING.md`: contributor workflow and testing expectations
- `CODE_OF_CONDUCT.md`: community standards and enforcement rules
- `SECURITY.md`: vulnerability reporting guidance
- `CHANGELOG.md`: notable project changes
- `docs/release.md`: release checklist, signing, and notarization workflow

## How to Build

### Prerequisites

- macOS 13.0+ (for SMAppService)
- Xcode 15.0+
- XcodeGen (`brew install xcodegen`)
- appdmg (`npm install -g appdmg`)
- Full Xcode selected (`xcode-select -p` should point to `/Applications/Xcode.app/...`)

### One-command release build

```bash
./scripts/build-release-artifacts.sh
```

### Full build flow

```bash
xcodegen generate
"/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild" -project Matcha.xcodeproj -scheme Matcha -configuration Release build
```

Build output:

`~/Library/Developer/Xcode/DerivedData/Matcha-*/Build/Products/Release/Matcha.app`

### Create DMG manually

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Matcha.app" -type d -path "*/Release/*.app" | head -1)
cat > /tmp/appdmg.json << 'JSON'
{
  "title": "Matcha",
  "window": { "size": { "width": 450, "height": 300 } },
  "contents": [
    { "type": "file", "path": "$APP_PATH", "name": "Matcha.app", "x": 100, "y": 80 },
    { "type": "link", "path": "/Applications", "name": "Applications", "x": 300, "y": 80 }
  ],
  "icon-size": 90
}
JSON
sed -i '' "s|\$APP_PATH|$APP_PATH|g" /tmp/appdmg.json
appdmg /tmp/appdmg.json Matcha.dmg
```

### Alternative command line build (without Xcode UI)

```bash
cd Sources
xcrun --sdk macosx swiftc -o Matcha main.swift AppDelegate.swift StatusBarController.swift MatchaManager.swift PowerManager.swift PreferencesManager.swift HistoryManager.swift BatterySleepSupport.swift
```

## Tests

```bash
xcodegen generate
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project Matcha.xcodeproj -scheme MatchaTests -sdk macosx test -destination 'platform=macOS'
```

Release artifact verification:

```bash
./scripts/build-release-artifacts.sh
```

## License

MIT
