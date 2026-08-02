#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/VirusTotal.xcodeproj"
SCHEME="VirusTotal"
CONFIGURATION="Release"
APP_NAME="VirusTotal"
VOLUME_NAME="VirusTotal"
BACKGROUND_PATH="$ROOT_DIR/Packaging/DMG/background.png"
ARTIFACTS_DIR="$ROOT_DIR/Artifacts"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/virustotal-dmg.XXXXXX")"

cleanup() {
    if [[ -n "${MOUNT_DIR:-}" && -d "$MOUNT_DIR" ]]; then
        hdiutil detach "$MOUNT_DIR" -quiet || true
    fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [[ ! -f "$BACKGROUND_PATH" ]]; then
    echo "Missing DMG background: $BACKGROUND_PATH" >&2
    exit 1
fi

mkdir -p "$ARTIFACTS_DIR"

echo "Building $APP_NAME.app..."
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$WORK_DIR/DerivedData" \
    clean build

APP_PATH="$WORK_DIR/DerivedData/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "Build succeeded, but app was not found: $APP_PATH" >&2
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist")
DMG_PATH="$ARTIFACTS_DIR/$APP_NAME-$VERSION.dmg"
RW_DMG_PATH="$WORK_DIR/$APP_NAME-rw.dmg"
STAGING_DIR="$WORK_DIR/staging"

rm -f "$DMG_PATH" "$RW_DMG_PATH"
mkdir -p "$STAGING_DIR/.background"

ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
cp "$BACKGROUND_PATH" "$STAGING_DIR/.background/background.png"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating writable DMG..."
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -format UDRW \
    -fs HFS+ \
    -ov \
    "$RW_DMG_PATH"

MOUNT_DIR=$(hdiutil attach "$RW_DMG_PATH" -readwrite -noverify -noautoopen | awk 'index($0, "/Volumes/") { print substr($0, index($0, "/Volumes/")); exit }')
if [[ -z "$MOUNT_DIR" || ! -d "$MOUNT_DIR" ]]; then
    echo "Could not mount DMG." >&2
    exit 1
fi
MOUNT_NAME="$(basename "$MOUNT_DIR")"

echo "Applying Finder layout..."
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$MOUNT_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set pathbar visible of container window to false
        set bounds of container window to {100, 100, 868, 644}
        set viewOptions to icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 112
        set background picture of viewOptions to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {222, 222}
        set position of item "Applications" of container window to {548, 222}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT_DIR" -quiet
MOUNT_DIR=""

echo "Compressing DMG..."
hdiutil convert "$RW_DMG_PATH" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" -ov

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "Created: $DMG_PATH"
