# Release Guide

This document describes the recommended release workflow for Matcha.

## Prerequisites

- Full Xcode selected via `xcode-select -p`
- `xcodegen`
- `appdmg`
- Apple Developer account (for public binary distribution)
- `xcrun notarytool` configured with an app-specific password or API key

## 1. Prepare

- Update `CHANGELOG.md`
- Confirm version in `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`)
- Run tests and validate no unintended files are staged

```bash
xcodegen generate
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project Matcha.xcodeproj -scheme MatchaTests -sdk macosx test -destination 'platform=macOS'
```

## 2. Build Artifacts

```bash
./scripts/build-release-artifacts.sh
```

Artifacts:

- App: `Build/DerivedData/Build/Products/Release/Matcha.app`
- DMG: `Build/Matcha.dmg`

## 3. Sign for Distribution

Set your signing identities first:

```bash
export APP_SIGN_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)"
export INSTALL_SIGN_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)"
```

Sign the app bundle:

```bash
codesign --force --deep --options runtime --timestamp \
  --sign "$APP_SIGN_IDENTITY" \
  Build/DerivedData/Build/Products/Release/Matcha.app
```

Optionally sign the DMG:

```bash
codesign --force --timestamp --sign "$INSTALL_SIGN_IDENTITY" Build/Matcha.dmg
```

## 4. Notarize and Staple

Submit for notarization (example with keychain profile):

```bash
xcrun notarytool submit Build/Matcha.dmg \
  --keychain-profile "AC_PROFILE" \
  --wait
```

Staple ticket:

```bash
xcrun stapler staple Build/Matcha.dmg
xcrun stapler staple Build/DerivedData/Build/Products/Release/Matcha.app
```

## 5. Verify

```bash
codesign --verify --deep --strict Build/DerivedData/Build/Products/Release/Matcha.app
spctl -a -vv Build/DerivedData/Build/Products/Release/Matcha.app
spctl -a -vv -t open Build/Matcha.dmg
shasum -a 256 Build/Matcha.dmg
```

Record the SHA256 in release notes so users can verify downloads.

## 6. Publish

- Create and push tag (for example: `v1.0.2`)
- Create GitHub release
- Upload notarized `Matcha.dmg`
- Paste changelog section + SHA256 into release notes

## Release Checklist

- [ ] Changelog updated
- [ ] Version updated in `project.yml`
- [ ] Tests passed
- [ ] Artifacts built
- [ ] App signed
- [ ] Notarization completed
- [ ] Stapling completed
- [ ] `spctl` checks passed
- [ ] SHA256 generated and published
- [ ] Tag pushed and GitHub release published
