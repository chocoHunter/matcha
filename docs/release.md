# Release Guide

This document describes the current release workflow for Matcha.

## Prerequisites

- Full Xcode installation selected via `xcode-select`
- XcodeGen
- appdmg
- Access to Apple signing credentials if you plan to distribute binaries publicly

## 1. Prepare the Release

- Confirm `README.md`, `README-CN.md`, and `CHANGELOG.md` are up to date
- Run tests
- Validate the target version number in `project.yml`
- Confirm no unintended local files are included

## 2. Build and Validate Artifacts

Run:

```bash
./scripts/build-release-artifacts.sh
```

This currently:

- Generates the Xcode project
- Builds the Release app
- Verifies the app bundle with `codesign --verify`
- Creates `Build/Matcha.dmg`
- Mounts the DMG and confirms `Matcha.app` is present

Artifacts:

- App: `Build/DerivedData/Build/Products/Release/Matcha.app`
- DMG: `Build/Matcha.dmg`

## 3. Run Manual Checks

Recommended checks before publishing:

- Launch the built app
- Verify each mode can be enabled and stopped
- Verify battery mode recovery paths
- Verify lid-close display sleep behavior in battery mode
- Re-open the lid and confirm normal recovery
- Test the **Repair Sleep Settings** flow

## 4. Sign and Notarize for Public Binary Distribution

The current local build script creates development-signed artifacts suitable for local testing.

Before distributing binaries publicly, complete these steps with your Apple Developer credentials:

- Sign the app with a Developer ID Application certificate
- Sign the DMG with a Developer ID Installer or preferred distribution approach
- Submit the app or DMG for notarization
- Staple the notarization ticket
- Re-run validation with `spctl`

Suggested final checks:

```bash
codesign --verify --deep --strict Build/DerivedData/Build/Products/Release/Matcha.app
spctl -a -vv Build/DerivedData/Build/Products/Release/Matcha.app
spctl -a -vv -t open Build/Matcha.dmg
```

## 5. Publish the Release

- Tag the release in git
- Push the tag
- Create a GitHub release
- Attach the notarized DMG
- Paste the relevant `CHANGELOG.md` notes into the release description

## Release Checklist

- [ ] Tests passed
- [ ] Release artifacts built
- [ ] Manual battery-mode checks completed
- [ ] App signed for distribution
- [ ] Notarization completed
- [ ] `spctl` checks passed
- [ ] Changelog updated
- [ ] Git tag created
- [ ] GitHub release published
