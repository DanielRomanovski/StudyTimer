#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
APP="$ROOT/dist/StudyTimer.app"
DMG_ROOT="$(mktemp -d)"
trap 'rm -rf "$DMG_ROOT"' EXIT HUP INT TERM

cd "$ROOT"
swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/StudyTimer "$APP/Contents/MacOS/StudyTimer"
cp Info.plist "$APP/Contents/Info.plist"
"$ROOT/scripts/create-app-icon.sh" "$APP/Contents/Resources/StudyTimer.icns"
codesign --force --deep --sign - "$APP"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$ROOT/dist/StudyTimer-$VERSION-macOS-arm64.dmg"
mkdir -p "$DMG_ROOT"
ditto "$APP" "$DMG_ROOT/StudyTimer.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -quiet -volname "StudyTimer $VERSION" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG"
printf 'Built %s and %s\n' "$APP" "$DMG"