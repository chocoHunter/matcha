#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/Build"
DERIVED_DATA_DIR="$BUILD_DIR/DerivedData"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/Release/Matcha.app"
DMG_PATH="$BUILD_DIR/Matcha.dmg"
XCODEBUILD="${XCODEBUILD:-/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild}"
XCODEGEN="${XCODEGEN:-xcodegen}"
APPDMG="${APPDMG:-appdmg}"
CREATE_DMG=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-dmg)
      CREATE_DMG=0
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--skip-dmg]" >&2
      exit 1
      ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command "$XCODEGEN"
require_command "$XCODEBUILD"
if [[ $CREATE_DMG -eq 1 ]]; then
  require_command "$APPDMG"
fi

mkdir -p "$BUILD_DIR"

echo "==> Generating Xcode project"
"$XCODEGEN" generate --spec "$ROOT_DIR/project.yml"

echo "==> Building Release app"
"$XCODEBUILD" \
  -project "$ROOT_DIR/Matcha.xcodeproj" \
  -scheme Matcha \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Release app not found at: $APP_PATH" >&2
  exit 1
fi

echo "==> Verifying app bundle signature"
codesign --verify --deep --strict "$APP_PATH"

echo "==> App ready"
du -sh "$APP_PATH"

if [[ $CREATE_DMG -eq 0 ]]; then
  echo "Skipped DMG creation"
  exit 0
fi

echo "==> Creating DMG"
TMP_JSON="$(mktemp /tmp/matcha-appdmg.XXXXXX.json)"
TMP_MOUNT=""
cleanup() {
  if [[ -n "$TMP_MOUNT" && -d "$TMP_MOUNT" ]]; then
    hdiutil detach "$TMP_MOUNT" >/dev/null 2>&1 || true
  fi
  rm -f "$TMP_JSON"
}
trap cleanup EXIT

cat > "$TMP_JSON" <<EOF
{
  "title": "Matcha",
  "window": {
    "size": { "width": 480, "height": 320 }
  },
  "icon-size": 96,
  "contents": [
    { "type": "file", "path": "$APP_PATH", "x": 140, "y": 150 },
    { "type": "link", "path": "/Applications", "x": 340, "y": 150 }
  ]
}
EOF

rm -f "$DMG_PATH"
"$APPDMG" "$TMP_JSON" "$DMG_PATH"

echo "==> Mounting DMG for verification"
ATTACH_OUTPUT="$(hdiutil attach -nobrowse "$DMG_PATH")"
printf '%s\n' "$ATTACH_OUTPUT"
TMP_MOUNT="$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F '\t' '/\/Volumes\// {print $3}' | tail -n 1)"

if [[ -z "$TMP_MOUNT" || ! -d "$TMP_MOUNT/Matcha.app" ]]; then
  echo "DMG verification failed: Matcha.app not found in mounted image" >&2
  exit 1
fi

codesign --verify --deep --strict "$TMP_MOUNT/Matcha.app"

echo "==> DMG contents"
ls -la "$TMP_MOUNT"

hdiutil detach "$TMP_MOUNT"
TMP_MOUNT=""

echo "==> Release artifacts ready"
echo "APP: $APP_PATH"
echo "DMG: $DMG_PATH"
